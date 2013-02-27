
 #include "ToastSampler.h"
 #include "I2CDiscoverable.h"
 #include "GlobalID.h"
 #include "metadata.h"
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

  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;

  discoverer_register_union_t attached[MAX_BUS_LEN];
  uint8_t toastState[MAX_BUS_LEN];
  uint8_t sensorMaps[MAX_BUS_LEN];

  toast_disconnection_record_t disconnection;
  toast_connection_record_t connection;
  
  uint32_t sampleInterval = DEFAULT_SAMPLE_INTERVAL;

  event void Boot.booted(){
    printf("sampler booting\n");
    printfflush();
    //TODO: some problem with this line?
//    call SettingsStorage.get(SS_KEY_SAMPLE_INTERVAL,
//      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    printf("sampler booted: using interval %lu\n", sampleInterval);
    printfflush();
    call Timer.startOneShot(sampleInterval);
  }

  event void Timer.fired(){
    uint8_t i;
    for (i=0; i < MAX_BUS_LEN; i++){
      toastState[i] = (toastState[i] == PRESENT)? UNKNOWN : FREE;
    }
    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t error){
    printf("startdone\n");
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
    printf("Checking for");
    printf("\n");

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
    printf("discovered ");
    {
      uint8_t i;
      for (i = 0; i < GLOBAL_ID_LEN; i++){
        printf(" %x", discovery->val.globalAddr[i]);
      }
      printf(": ");
    }
    //check if this was previously-attached
    if( find(discovery->val.globalAddr, &k) ){
      printf("found @%u ", k);
      toastState[k] = PRESENT;
    }else{
      for (k = 0; k < MAX_BUS_LEN; k++){
        if (toastState[k] == FREE){
          toastState[k] = NEW;
          memcpy(&attached[k].val.globalAddr, 
            discovery->val.globalAddr, 
            GLOBAL_ID_LEN);
          printf("stored @%u ", k);
          break;
        }
      }
    }
    if (k < MAX_BUS_LEN){
      //always required: even if it's a re-discover, no guarantee that
      //local toast addr is constant
      attached[k].val.localAddr =  discovery->val.localAddr;
      printf("local: %x\r\n", attached[k].val.localAddr);
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
    printf("discovery done\n");
    mdSynchIndex = 0;
    post nextMdSynch();
  }

  task void nextMdSynch(){
    printf("synch %u\n", mdSynchIndex);

    if (mdSynchIndex == MAX_BUS_LEN){
      printf("synch done\n");
      //ok, ready to sample
      toastSampleIndex = 0;
      post nextSampleSensors();
    }else{
      if (toastState[mdSynchIndex] == NEW){
        error_t error = call I2CTLVStorageMaster.loadTLVStorage(
          attached[mdSynchIndex].val.localAddr,
          i2c_msg);
        printf("synch new @%u\n", mdSynchIndex);

        //skip it if we can't read it.
        if (error != SUCCESS){
          printf("couldn't read");
          mdSynchIndex ++;
          post nextMdSynch();
        }

      } else if (toastState[mdSynchIndex] == UNKNOWN){
        printf("synch absent @%u\n", mdSynchIndex);
        toastState[mdSynchIndex] = ABSENT;
        post recordDisconnection();
      } else if (toastState[mdSynchIndex] == PRESENT ||
          toastState[mdSynchIndex] == FREE){
        printf("no synch for %u\n", mdSynchIndex);
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

    printf("TLV loaded: %x\n", error);
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
        printf("no sensor assignments found.\r\n");
        //no sensors attached.
        sensorMaps[mdSynchIndex] = 0x00;
      } else{
        uint8_t i;
        sensor_assignment_t* assignments =
          (sensor_assignment_t*)&entry->data.b;
        printf("Sensor assignments found.\n");
        sensorMaps[mdSynchIndex] = 0x00;
        //mark connected sensor channels in RAM
        for (i = 0; i < 8; i++){
          if( assignments[i].sensorType != SENSOR_TYPE_NONE){
            sensorMaps[mdSynchIndex] |= (0x01 << i);
          }
        }
      }
      printf("Sensor map for %u: %x\n", 
        mdSynchIndex, 
        sensorMaps[mdSynchIndex]);

      err = call LogWrite.append(&connection, sizeof(connection));
      printf("Appending: %p %u: %x\n", &connection, sizeof(connection), err);
      printfflush();
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
    printf("append done\n");
    printfflush();
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
  }
  
  task void nextSampleSensors(){
    if (toastSampleIndex == MAX_BUS_LEN){
      call SplitControl.stop();
      return;
    }else{
      if (toastState[toastSampleIndex] == PRESENT){
        //TODO: set up an i2c adc-read message (use sensorMap for
        //  toast)
        //TODO: sampler settings should come from settings storage
        //  (alt. part of toast's TLVStorage or internalFlash)
        //TODO: send sample command to current toast's local addr

        //TODO: remove toastSampleIndex++ (debug code)
        toastSampleIndex++;
        post nextSampleSensors();
      } else {
        toastSampleIndex++;
        post nextSampleSensors();
      }
    }
  }

  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error,
      uint16_t slaveAddr, i2c_message_t* cmdMsg_, i2c_message_t*
      responseMsg_, adc_response_t* response){
    return responseMsg_;
  }


  event void LogWrite.syncDone(error_t error){ }
  event void LogWrite.eraseDone(error_t error){}
  event void SplitControl.stopDone(error_t error){
    printf("bus off\n");
    call Timer.startOneShot(sampleInterval);
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){}

}
