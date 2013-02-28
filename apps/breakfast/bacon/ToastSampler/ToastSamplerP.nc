
 #include "ToastSampler.h"
 #include "I2CDiscoverable.h"
 #include "GlobalID.h"
 #include "metadata.h"
 #include "RebootCounter.h"
 #include "printf.h"
module ToastSamplerP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as StartupTimer;

  uses interface SplitControl;
  uses interface I2CDiscoverer;

  uses interface I2CTLVStorageMaster;
  uses interface TLVUtils;

  uses interface I2CADCReaderMaster;

  uses interface I2CSynchMaster;

  uses interface SettingsStorage;
} implementation {

  enum{
    LOCAL_ADDR = 0x40,
    TOAST_ADDR_START = 0x41,
  };

  enum{
    FREE = 0x00,
    PRESENT = 0x01,
    UNKNOWN = 0x02,
    ABSENT = 0x03,
    NEW = 0x04,
  };
  
  bool busy = FALSE;

  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;
  adc_response_t* lastSample;
  sample_record_t sampleRec;

  discoverer_register_union_t attached[MAX_BUS_LEN];
  uint8_t toastState[MAX_BUS_LEN];
  uint8_t sensorMaps[MAX_BUS_LEN];

  toast_disconnection_record_t disconnection;
  toast_connection_record_t connection;
  bool synchingMetadata = FALSE;
  
  uint32_t sampleInterval = DEFAULT_SAMPLE_INTERVAL;


  event void Boot.booted(){
    call SettingsStorage.get(SS_KEY_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    sampleRec.recordType = RECORD_TYPE_SAMPLE;
    call Timer.startPeriodic(sampleInterval);
  }

  event void Timer.fired(){
    uint8_t i;
    if (!busy){
      busy = TRUE;
      for (i=0; i < MAX_BUS_LEN; i++){
        toastState[i] = (toastState[i] == PRESENT)? UNKNOWN : FREE;
      }
      call SplitControl.start();
    }
  }

  event void SplitControl.startDone(error_t error){
    call StartupTimer.startOneShot(256);
  }
  
  event void StartupTimer.fired(){
    call I2CDiscoverer.startDiscovery(TRUE, TOAST_ADDR_START);
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return LOCAL_ADDR;
  }

  bool find(uint8_t* globalAddr, uint8_t* index){
    uint8_t i, k;

    for (i = 0; i < MAX_BUS_LEN; i++){
      bool found = (toastState[i] != FREE);
      for (k = 0; k < GLOBAL_ID_LEN && found; k++){
        if (globalAddr[k] != attached[i].val.globalAddr[k]){
          found = FALSE;
          break;
        }
      }
      if (found){
        *index = i;
        return TRUE;
      }
    }
    return FALSE;
  }
  
  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery){
    uint8_t k;
    //check if this was previously-attached
    if( find(discovery->val.globalAddr, &k) ){
      toastState[k] = PRESENT;
    }else{
      for (k = 0; k < MAX_BUS_LEN; k++){
        if (toastState[k] == FREE){
          toastState[k] = NEW;
          memcpy(&attached[k].val.globalAddr, 
            discovery->val.globalAddr, 
            GLOBAL_ID_LEN);
          break;
        }
      }
    }
    if (k < MAX_BUS_LEN){
      //always required: even if it's a re-discover, no guarantee that
      //local toast addr is constant
      attached[k].val.localAddr =  discovery->val.localAddr;
    } else {
      printf("No space left on bus, ignore!");
    }

    return discovery;
  }
  
  uint8_t mdSynchIndex;
  uint8_t toastSampleIndex;

  task void nextMdSynch();
  task void nextSampleSensors();
  
  task void recordDisconnection();

  event void I2CDiscoverer.discoveryDone(error_t error){
    mdSynchIndex = 0;
    synchingMetadata = TRUE;
    post nextMdSynch();
  }

  task void nextMdSynch(){

    if (mdSynchIndex == MAX_BUS_LEN){
      //ok, ready to sample
      toastSampleIndex = 0;
      synchingMetadata = FALSE;
      post nextSampleSensors();
    }else{
      if (toastState[mdSynchIndex] == NEW){
        error_t error = call I2CTLVStorageMaster.loadTLVStorage(
          attached[mdSynchIndex].val.localAddr,
          i2c_msg);

        //skip it if we can't read it.
        if (error != SUCCESS){
          printf("couldn't read");
          mdSynchIndex ++;
          post nextMdSynch();
        }

      } else if (toastState[mdSynchIndex] == UNKNOWN){
        toastState[mdSynchIndex] = ABSENT;
        post recordDisconnection();
      } else if (toastState[mdSynchIndex] == PRESENT ||
          toastState[mdSynchIndex] == FREE){
        mdSynchIndex ++;
        post nextMdSynch();
      }

    }
  }


  task void recordDisconnection(){
    disconnection.recordType = RECORD_TYPE_TOAST_DISCONNECTED;
    memcpy(&disconnection.globalAddr, 
      &attached[mdSynchIndex].val.globalAddr,
      GLOBAL_ID_LEN);
    if( SUCCESS != call LogWrite.append(&disconnection, sizeof(disconnection))){
      toastState[mdSynchIndex] = FREE;
      mdSynchIndex++;
    }
  }
  

  event void I2CTLVStorageMaster.loaded(error_t error, i2c_message_t* msg_){
    tlv_entry_t* entry;
    void* tlvs = call I2CTLVStorageMaster.getPayload(msg_);
    error_t err;

    if (error == SUCCESS){
      //set up connection record header
      connection.recordType = RECORD_TYPE_TOAST_CONNECTED;
      //copy in the contents of the TLV storage
      memcpy(&connection.tlvContents,
        tlvs, 
        SLAVE_TLV_LEN);

      //record number of sensors locally
      if( 0 == call TLVUtils.findEntry(TAG_TOAST_ASSIGNMENTS,
          0,
          &entry,
          tlvs)){
        //no sensors attached.
        sensorMaps[mdSynchIndex] = 0x00;
      } else{
        uint8_t i;
        sensor_assignment_t* assignments =
          (sensor_assignment_t*)&entry->data.b;
        sensorMaps[mdSynchIndex] = 0x00;
        //mark connected sensor channels in RAM
        for (i = 0; i < 8; i++){
          if( assignments[i].sensorType != SENSOR_TYPE_NONE){
            sensorMaps[mdSynchIndex] |= (0x01 << i);
          }
        }
      }

      err = call LogWrite.append(&connection, sizeof(connection));
      if( SUCCESS != err){
        printf("append failed\n");
        printfflush();
        //if append fails, mark this as free so that it will try again
        // on the next scan.
        toastState[mdSynchIndex] = FREE;
        mdSynchIndex++;
        post nextMdSynch();
      }

    }else{
      printf("load failed\n");
      toastState[mdSynchIndex] = FREE;
      mdSynchIndex++;
      post nextMdSynch();
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
    if (synchingMetadata){
      if (error == SUCCESS){
        if (toastState[mdSynchIndex] == NEW){
          toastState[mdSynchIndex] = PRESENT;
        } else if (toastState[mdSynchIndex] == ABSENT){
          toastState[mdSynchIndex] = FREE;
        }
      } else {
        toastState[mdSynchIndex] = FREE;
      }
      mdSynchIndex++;
      post nextMdSynch();
    }else{
      toastSampleIndex++;
      post nextSampleSensors();
    }
  }
  
  task void nextSampleSensors(){
    if (toastSampleIndex == MAX_BUS_LEN){
      call SplitControl.stop();
      return;
    }else{
      if (toastState[toastSampleIndex] == PRESENT 
          && sensorMaps[toastSampleIndex]){
        adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2c_msg);
        error_t err;
        uint8_t i;
        uint8_t cmdIndex = 0;
        for (i=0; i < ADC_NUM_CHANNELS; i++){
          if ( (0x01 << i) & sensorMaps[toastSampleIndex]){
            //TODO: read these from settings storage? Toast flash?
            //delay MS is the most important factor (warm-up time)
            uint32_t delayMS = 0;
            uint16_t samplePeriod = 0;
            uint8_t sref = 1;
            uint8_t ref2_5v = TRUE;
            uint8_t adc12ssel = 3;
            uint8_t adc12div = 0;
            //sht: set to 1024 ticks = 1 mS (good to 2.8 ohms)
            uint8_t sht = 0xff;
            uint8_t sampcon_ssel = 1;
            uint8_t sampcon_id = 0;


            cmd->cfg[cmdIndex].delayMS = delayMS;
            cmd->cfg[cmdIndex].samplePeriod = samplePeriod;
            cmd->cfg[cmdIndex].config.inch = i;
            cmd->cfg[cmdIndex].config.sref = sref;
            cmd->cfg[cmdIndex].config.ref2_5v = ref2_5v;
            cmd->cfg[cmdIndex].config.adc12ssel = adc12ssel;
            cmd->cfg[cmdIndex].config.adc12div = adc12div;
            cmd->cfg[cmdIndex].config.sht = sht;
            cmd->cfg[cmdIndex].config.sampcon_ssel = sampcon_ssel;
            cmd->cfg[cmdIndex].config.sampcon_id = sampcon_id;
            cmdIndex++;
          }
        }
        //mark end-of-sequence
        cmd->cfg[cmdIndex].config.inch = INPUT_CHANNEL_NONE;
        
        err = call I2CADCReaderMaster.sample(
          attached[toastSampleIndex].val.localAddr, 
          i2c_msg);
        if (err != SUCCESS){
          toastSampleIndex++;
          post nextSampleSensors();
        }
      } else {
        toastSampleIndex++;
        post nextSampleSensors();
      }
    }
  }

   
  task void appendSample(){
    uint8_t i;
    error_t err;
    storage_len_t recordLen = sizeof(sample_record_t) - (sizeof(adc_sample_t)*ADC_NUM_CHANNELS);
    memcpy(&sampleRec.toastAddr, 
      &attached[toastSampleIndex].val.globalAddr,
      GLOBAL_ID_LEN);
    for (i = 0; i < ADC_NUM_CHANNELS; i++){
      if (lastSample->samples[i].inputChannel == INPUT_CHANNEL_NONE){
        break;
      }else{
        //TODO: please don't give me any word alignment bullshit
        recordLen += sizeof(adc_sample_t);
        //is this assignment legit?
        sampleRec.samples[i] = lastSample->samples[i];
        //TODO: remove debug code: make it easier to spot in dump
        sampleRec.samples[i].sampleTime = sampleRec.samples[i].inputChannel;
        sampleRec.samples[i].sample = sampleRec.samples[i].inputChannel;
      }
    }
    err = call LogWrite.append(&sampleRec, recordLen);
    if (err != SUCCESS){
      toastSampleIndex++;
      post nextSampleSensors();
    }
  }

  event void I2CSynchMaster.synchDone(error_t error, 
      uint16_t slaveAddr, 
      synch_tuple_t tuple){
    if (error == SUCCESS){
      //e.g. local = 100, remote = 10, sample = 50
      //local-remote = 90  
      // +50 = 140 
      // local = 200 remote =110 sample =50
      // local - remote = 90
      // +50 = 140
      sampleRec.baseTime = tuple.localTime - tuple.remoteTime;
      post appendSample();
    }else{
      toastSampleIndex++;
      post nextSampleSensors();
    }

  }

  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error,
      uint16_t slaveAddr, i2c_message_t* cmdMsg_, 
      i2c_message_t* responseMsg_, 
      adc_response_t* response){

    if (error == SUCCESS){
      i2c_message_t* swp = i2c_msg;
      i2c_msg = responseMsg_;
      lastSample = response;
      call I2CSynchMaster.synch(slaveAddr);
      return swp;
    }else{
      toastSampleIndex++;
      post nextSampleSensors();
      return responseMsg_;
    }
  }


  event void LogWrite.syncDone(error_t error){ }
  event void LogWrite.eraseDone(error_t error){}
  event void SplitControl.stopDone(error_t error){ 
    busy = FALSE;
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){}

}
