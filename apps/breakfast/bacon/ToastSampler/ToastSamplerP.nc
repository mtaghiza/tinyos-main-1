module ToastSamplerP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;

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

  discoverer_register_union_t attached[MAX_BUS_LEN];
  uint8_t toastState[MAX_BUS_LEN];
  uint8_t numSensors[MAX_BUS_LEN];

  event void Boot.booted(){
    //TODO: read scan interval/sample interval from setting storage
    //TODO: start timer
  }

  event void Timer.fired(){
    for (i=0; i < MAX_BUS_LEN; i++){
      toastState[i] = (toastState[i] == PRESENT)? UNKNOWN : FREE;
    }
    call I2CDiscoverer.startDiscovery(TRUE, TOAST_ADDR_START);
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return LOCAL_ADDR;
  }

  bool find(uint8_t* globalAddr, uint8_t* index){
    uint8_t i, k;
    for (i = 0; i < MAX_BUS_LEN; i++){
      bool found = TRUE;
      for (k = 0; k < GLOBAL_ID_LEN; k++){
        if (globalAddr[k] != attached[i]->val.globalAddr[k]){
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
    uint8_t i,k;
    bool isNew = TRUE;

    //check if this was previously-attached
    if( find(discovery->val.globalAddr, &k) ){
      toastState[k] = PRESENT;
      isNew = FALSE;
    }

    if (isNew){
      for (k = 0; k < MAX_BUS_LEN; k++){
        if (toastState[k] == FREE){
          toastState[k] = NEW;
          attached[k].localAddr =  discovery->val.localAddr;
          memcpy(&attached[k].globalAddr, 
            discovery->val.globalAddr, 
            GLOBAL_ID_LEN);
        }
      }
    }

    return discovery;
  }
  
  uint8_t mdSynchIndex;
  event void I2CDiscoverer.discoveryDone(error_t error){
    mdSynchIndex = 0;
    post nextMdSynch();
  }

  task void nextMdSynch(){
    if (mdSynchIndex == MAX_BUS_LEN){
      //ok, ready to sample
      toastSampleIndex = 0;
      post sampleSensors();
    }else{
      if (toastState[mdSynchIndex] == NEW){
        error_t error = call I2CTLVStorageMaster.loadTLVStorage(
          attached[mdSynchIndex].val.localAddr,
          i2c_msg);

        //skip it if we can't read it.
        if (error != SUCCESS){
          mdSynchIndex ++;
          post nextMdSynch();
        }

      } else if (toastState[mdSynchIndex] == UNKNOWN){
        toastState[mdSynchIndex] = ABSENT;
        post recordDisconnection();
      } else if (toastState[mdSynchIndex] == PRESENT ||
          toastState[mdSynchIndex] == FREE){
        mdSynchIndex ++;
        post nextMdSynch;
      }

    }
  }
  typedef struct toast_disconnection_record_t{
    uint8_t recordType;
    uint8_t globalAddr[GLOBAL_ID_LEN];
  } toast_disconnection_record_t;
  toast_disconnection_record_t disconnection;

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
  
  //TODO: make this a union to save RAM?
  typedef struct sensor_association_record_t{
    uint8_t recordType;
    uint8_t globalAddr[GLOBAL_ID_LEN];
    sensor_assignment_t assignments[8];
  } sensor_association_record_t;

  sensor_association_record_t assoc;

  event void I2CTLVStorageMaster.loaded(error_t error, i2c_message_t* msg_){
    tlv_entry_t* entry;
    tlvs = call I2CTLVStorageMaster.getPayload(msg_);
    if (error == SUCCESS){
      uint8_t i;
      //set up association record header
      assoc.recordType = RECORD_TOAST_ATTACHED;
      memcpy(&assoc.globalAddr,
        attached[mdSynchIndex].val.globalAddr, 
        GLOBAL_ID_LEN);
      //fill in association record body
      if( SUCCESS == call TLVUtils.findEntry(SENSOR_ATTACHMENTS_ID,
          0,
          &entry,
          tlvs)){
        sensor_assignment_t* assignments =
          (sensor_assignment_t*)&entry->data.b;
        //fill in/count up assignments
        for (i = 0; i< 8; i++){
          assoc.assignments[i].sensorType = 
          if( assignments[i].sensorType != SENSOR_TYPE_NONE){
            numSensors[mdSynchIndex]++;
            assoc.assignments[i].sensorId = assignments[i].sensorId;
          }else{
            assoc.assignments[i].sensorId = 0;
          }
        }
      } else{
        //No sensor-assignments? record none-found
        for (i = 0; i < 8 ; i++){
          assoc.assignments[i].sensorType = SENSOR_TYPE_NONE; 
          assoc.assignments[i].sensorId = 0; 
        }
        numSensors[mdSynchIndex] = 0;
      }

      if( SUCCESS == call LogWrite.append(&assoc, sizeof(assoc))){
        //if append fails, mark this as free so that it will try again
        // on the next scan.
        toastState[mdSynchIndex] = FREE;
        mdSynchIndex++;
        post nextMdSynch();
      }

    }else{
      toastState[mdSynchIndex] = FREE;
      mdSynchIndex++;
      post nextMdSynch();
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
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
  
  task void sampleSensors(){
    if (toastSampleIndex == MAX_BUS_LEN){
      return;
    }else{
      if (toastState[toastSampleIndex] == PRESENT){
        //TODO: set up an i2c adc-read message (use number of sensors for
        //toast)
        //TODO: sampler settings should come from settings storage?
        //TODO: send sample command to current toast's local addr
        //TODO: remove this (debug code)
        toastSampleIndex++;
        post sampleSensors();
      } else {
        toastSampleIndex++;
        post sampleSensors();
      }
    }
  }


}
