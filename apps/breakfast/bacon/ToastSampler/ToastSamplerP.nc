
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
  uint8_t numSensors[MAX_BUS_LEN];

  toast_disconnection_record_t disconnection;
  sensor_association_record_t assoc;
  
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
    for (k = 0; k < GLOBAL_ID_LEN; k++){
      printf(" %x", globalAddr[k]);
    }
    printf("\n");

    for (i = 0; i < MAX_BUS_LEN; i++){
      bool found = TRUE;
      for (k = 0; k < GLOBAL_ID_LEN; k++){
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
    bool isNew = TRUE;
    printf("discovered\n");
    //check if this was previously-attached
    if( find(discovery->val.globalAddr, &k) ){
      printf("found @%u\n", k);
      toastState[k] = PRESENT;
      isNew = FALSE;
    }

    if (isNew){
      printf("new\n");
      for (k = 0; k < MAX_BUS_LEN; k++){
        if (toastState[k] == FREE){
          toastState[k] = NEW;
          attached[k].val.localAddr =  discovery->val.localAddr;
          memcpy(&attached[k].val.globalAddr, 
            discovery->val.globalAddr, 
            GLOBAL_ID_LEN);
          printf("stored @%u\n", k);
          break;
        }
      }
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
      uint8_t i;
      //set up association record header
      assoc.recordType = RECORD_TYPE_TOAST_DISCONNECTED;
      memcpy(&assoc.globalAddr,
        attached[mdSynchIndex].val.globalAddr, 
        GLOBAL_ID_LEN);
      //fill in association record body
      if( SUCCESS == call TLVUtils.findEntry(TAG_TOAST_ASSIGNMENTS,
          0,
          &entry,
          tlvs)){
        sensor_assignment_t* assignments =
          (sensor_assignment_t*)&entry->data.b;
        printf("Toast assignments found\n");
        //fill in/count up assignments
        for (i = 0; i< 8; i++){
          assoc.assignments[i].sensorType = assignments[i].sensorType;
          if( assignments[i].sensorType != SENSOR_TYPE_NONE){
            numSensors[mdSynchIndex]++;
            assoc.assignments[i].sensorId = assignments[i].sensorId;
          }else{
            assoc.assignments[i].sensorId = 0;
          }
        }
      } else{
        printf("no assignments found.\n");
        //No sensor-assignments? record none-found
        for (i = 0; i < 8 ; i++){
          assoc.assignments[i].sensorType = SENSOR_TYPE_NONE; 
          assoc.assignments[i].sensorId = 0; 
        }
        numSensors[mdSynchIndex] = 0;
      }
      printf("Sensors for %u: %u\n", 
        mdSynchIndex, 
        numSensors[mdSynchIndex]);

      //TODO: this append call is never getting a matching appendDone.
      err = call LogWrite.append(&assoc, sizeof(assoc));
      printf("Appending: %p %u: %x\n", &assoc, sizeof(assoc), err);
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
        //TODO: set up an i2c adc-read message (use number of sensors for
        //toast)
        //TODO: sampler settings should come from settings storage?
        //TODO: send sample command to current toast's local addr
        //TODO: remove this (debug code)
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
//    call Timer.startOneShot(sampleInterval);
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){}

}
