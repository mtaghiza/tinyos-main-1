
 #include "ToastSampler.h"
module DummyToastP {
  provides interface SplitControl;
  provides interface I2CDiscoverer;

  provides interface I2CTLVStorageMaster;
  uses interface TLVUtils;

  provides interface I2CADCReaderMaster;

  provides interface I2CSynchMaster;

  uses interface LocalTime<T32khz>;
  uses interface Boot;
} implementation {
  task void startDoneTask(){ 
    signal SplitControl.startDone(SUCCESS);
  }

  command error_t SplitControl.start(){
    post startDoneTask();
    return SUCCESS;
  } 

  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.stop(){
    post stopDoneTask();
    return SUCCESS;
  } 

  task void discoveryDoneTask(){
    signal I2CDiscoverer.discoveryDone(SUCCESS);
  }
  
  discoverer_register_union_t d;
  task void discoveredTask(){
    uint8_t i;
    for (i=0; i < GLOBAL_ID_LEN-1; i++){
      d.val.globalAddr[i] = 0x00;
    }
    d.val.globalAddr[GLOBAL_ID_LEN-1] = TOS_NODE_ID;
    signal I2CDiscoverer.discovered(&d); 
    post discoveryDoneTask();
  }

  command error_t I2CDiscoverer.startDiscovery(bool reset, 
      uint16_t addrStart){
    d.val.localAddr = addrStart;
    post discoveredTask();
    return SUCCESS;
  }

  i2c_message_t* m;
  command void* I2CTLVStorageMaster.getPayload(i2c_message_t* msg){
    return (void*)msg;
  }

  uint8_t dummyTLV[SLAVE_TLV_LEN];
  
  typedef struct dummy_tlv_entry{
    uint8_t tag;
    uint8_t len;
    sensor_assignment_t assignments[8];
  } dummy_tlv_entry_t;
  
  event void Boot.booted(){
    uint8_t i;
    dummy_tlv_entry_t tlve;
    global_id_entry_t gid;
    //fill tlv with 0xff, then set up an initial TAG_EMPTY to cover
    //the entire storage area.
    memset(dummyTLV, 0xff, SLAVE_TLV_LEN);
    dummyTLV[2] = TAG_EMPTY;
    dummyTLV[3] = 60;
    //put in some toast assignments
    for (i=0; i < 8; i++){
      tlve.assignments[i].sensorType = i+1;
      tlve.assignments[i].sensorId = TOS_NODE_ID;
    }
    tlve.tag = TAG_TOAST_ASSIGNMENTS;
    tlve.len = 8*sizeof(sensor_assignment_t);
    call TLVUtils.addEntry(tlve.tag,
      tlve.len,
      (tlv_entry_t*)(&tlve),
      dummyTLV,
      0);
    //stick a global id in there, too.
    gid.header.tag = TAG_GLOBAL_ID;
    gid.header.len = GLOBAL_ID_LEN;
    for (i = 0 ; i < GLOBAL_ID_LEN; i++){
      gid.id[i] = i;
    }
    call TLVUtils.addEntry(gid.header.tag, 
      gid.header.len, (&gid.header), dummyTLV, 0);
  }

  task void loadedTask(){
    memcpy(m, dummyTLV, SLAVE_TLV_LEN);
    signal I2CTLVStorageMaster.loaded(SUCCESS, m);
  }

  command error_t I2CTLVStorageMaster.loadTLVStorage(uint16_t slaveAddr, 
      i2c_message_t* msg){
    m = msg;
    post loadedTask();
    return SUCCESS;
  }

  task void persistedTask(){
    signal I2CTLVStorageMaster.persisted(SUCCESS, m);
  }

  command error_t I2CTLVStorageMaster.persistTLVStorage(
      uint16_t slaveAddr, i2c_message_t* msg){
    m = msg;
    post persistedTask();
    return SUCCESS;
  }

  command adc_reader_pkt_t* I2CADCReaderMaster.getSettings(i2c_message_t* msg){
    return (adc_reader_pkt_t*)msg;
  }
  command adc_response_t* I2CADCReaderMaster.getResults(i2c_message_t* msg){
    return (adc_response_t*)msg;
  }
  
  uint16_t sa;

  task void sampleDoneTask(){
    uint8_t i;
    adc_response_t* r = (adc_response_t*)m;
    for (i=0; i < 8; i++){
      r->samples[i].inputChannel = i;
      r->samples[i].sampleTime = 10*i;
      r->samples[i].sample = 2*i;
    }
    r->samples[8].inputChannel = INPUT_CHANNEL_NONE;
    signal I2CADCReaderMaster.sampleDone(SUCCESS,
      sa, m, m, r);
  }

  command error_t I2CADCReaderMaster.sample(uint16_t slaveAddr,
      i2c_message_t* msg){
    sa = slaveAddr;
    m = msg;
    post sampleDoneTask();
    return SUCCESS;
  }

  task void synchDoneTask(){
    synch_tuple_t tuple;
    tuple.localTime32k = call LocalTime.get();
    tuple.localTimeMilli = tuple.localTime32k >> 5;
    tuple.remoteTime = 0;
    signal I2CSynchMaster.synchDone(SUCCESS, sa, tuple);
  }

  command error_t I2CSynchMaster.synch(uint16_t slaveAddr){
    sa = slaveAddr;
    post synchDoneTask();
    return SUCCESS;
  }

}
