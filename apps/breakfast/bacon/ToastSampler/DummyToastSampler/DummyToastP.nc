/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


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
  uses interface ActiveMessageAddress;
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
  

  uint8_t dummyTLV[SLAVE_TLV_LEN];

  discoverer_register_union_t d;
  task void discoveredTask(){
    uint8_t i;
    global_id_entry_t* gid;
    call TLVUtils.findEntry(TAG_GLOBAL_ID, 0, (tlv_entry_t**)(&gid), dummyTLV);
    for (i=0; i < GLOBAL_ID_LEN; i++){
      d.val.globalAddr[i] = gid->id[i];
    }
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
      tlve.assignments[i].sensorId = call ActiveMessageAddress.amAddress();
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
    gid.id[0] = TOS_NODE_ID;
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

  async event void ActiveMessageAddress.changed(){}

}
