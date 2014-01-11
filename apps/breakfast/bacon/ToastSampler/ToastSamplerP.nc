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
 #include "I2CDiscoverable.h"
 #include "GlobalID.h"
 #include "metadata.h"
 #include "RebootCounter.h"
// #include <stdio.h>
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
  
  #if ENABLE_PRECISION_TIMESTAMP == 1
  uses interface I2CSynchMaster;
  #endif

  uses interface SettingsStorage;

//  uses interface LogPrintf;
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
  short_sample_record_t sampleRec;

  discoverer_register_union_t attached[MAX_BUS_LEN];
  uint8_t toastState[MAX_BUS_LEN];
  uint8_t sensorMaps[MAX_BUS_LEN];

  toast_disconnection_record_t disconnection;
  toast_connection_record_t connection;
  bool synchingMetadata = FALSE;
  
  uint32_t toastBase;
  uint8_t failCount = 0;


  event void Boot.booted(){
    nx_uint32_t sampleInterval;
    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
    #if CONFIGURABLE_TOAST_SAMPLE_INTERVAL == 1
      call SettingsStorage.get(SS_KEY_TOAST_SAMPLE_INTERVAL,
        (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    #endif
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    sampleRec.recordType = RECORD_TYPE_SAMPLE;
    disconnection.rebootCounter = sampleRec.rebootCounter;
    connection.rebootCounter = sampleRec.rebootCounter;
//    printf("booted: %lu\r\n", sampleInterval);
//    {
//      char buf[20];
//      uint8_t len= sprintf(buf, "booted: %lu\r\n", sampleInterval);
//      call LogPrintf.log((uint8_t*)buf, len);
//    }
    call Timer.startOneShot(sampleInterval);
  }


  event void Timer.fired(){
    nx_uint32_t sampleInterval;
    error_t error;
    uint8_t i;
    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
    #if CONFIGURABLE_TOAST_SAMPLE_INTERVAL == 1
    error = call SettingsStorage.get(SS_KEY_TOAST_SAMPLE_INTERVAL,
        (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    #endif
    call Timer.startOneShotAt(call Timer.gett0() + call Timer.getdt(), 
      sampleInterval);
    if (!busy){
      busy = TRUE;
      for (i=0; i < MAX_BUS_LEN; i++){
        toastState[i] = (toastState[i] == PRESENT)? UNKNOWN : FREE;
      }
      call SplitControl.start();
    }else{
      failCount ++;
      if (failCount > MAX_TOAST_FAILS){
        printf("Toast fail count exceeded, resetting\r\n");
        atomic{
          WDTCTL = 0;
        }
      }
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
  task void nextSynch();
  
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
      post nextSynch();
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
        }else{
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
    disconnection.time = call Timer.getNow();
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
      connection.time = call Timer.getNow();
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
      post nextSynch();
    }
  }
  
  task void nextSynch(){
    if (toastSampleIndex == MAX_BUS_LEN){
      printf("done sampling, stopping\r\n");
      call SplitControl.stop();
      return;
    }else{
      #if ENABLE_PRECISION_TIMESTAMP == 1
      if (toastState[toastSampleIndex] == PRESENT 
          && sensorMaps[toastSampleIndex]){
        error_t error = call I2CSynchMaster.synch(attached[toastSampleIndex].val.localAddr);

        if (SUCCESS != error){
          toastSampleIndex++;
          post nextSynch();
        }
      } else {
        toastSampleIndex++;
        post nextSynch();
      }
      #else 
      if (toastState[toastSampleIndex] == PRESENT 
          && sensorMaps[toastSampleIndex]){
        post nextSampleSensors();
      }else{
        toastSampleIndex++;
        post nextSynch();
      }
      #endif
    }
  }
  
  #if ENABLE_PRECISION_TIMESTAMP == 1
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
      sampleRec.baseTime = tuple.localTimeMilli;
      toastBase = tuple.remoteTime;
      post nextSampleSensors();
    }else{
      toastSampleIndex++;
      post nextSynch();
    }
  }
  #endif

  task void nextSampleSensors(){
    adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2c_msg);
    error_t err;
    uint8_t i;
    uint8_t cmdIndex = 0;
    for (i=0; i < ADC_NUM_CHANNELS; i++){
      if ( (0x01 << i) & sensorMaps[toastSampleIndex]){
        //TODO: read these from settings storage? Toast flash?
        //delay MS is the most important factor (warm-up time)
        uint32_t delayMS = 5;
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
        //The following line reads 1/2 supply voltage
        //cmd->cfg[cmdIndex].config.inch = 0x0b;
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
    #if ENABLE_PRECISION_TIMESTAMP == 0
    sampleRec.baseTime = call Timer.getNow();
    #endif
    if (err != SUCCESS){
      toastSampleIndex++;
      post nextSynch();
    }
  }

   
  task void appendSample(){
    uint8_t i;
    error_t err;
    uint32_t sampleTimeAcc = 0;
    uint8_t numSamples = 0;
    storage_len_t recordLen = sizeof(short_sample_record_t) -
      (sizeof(uint16_t)*ADC_NUM_CHANNELS);
    memcpy(&sampleRec.samplerID, 
      &attached[toastSampleIndex].val.globalAddr,
      GLOBAL_ID_LEN);
    for (i = 0; i < ADC_NUM_CHANNELS; i++){
      if (lastSample->samples[i].inputChannel == INPUT_CHANNEL_NONE){
        break;
      }else{
        recordLen += sizeof(uint16_t);
        sampleRec.samples[i] = lastSample->samples[i].sample;
        #if ENABLE_PRECISION_TIMESTAMP == 0
        if (i ==0){
          toastBase = lastSample->samples[i].sampleTime;
        }
        #endif
        //accumulate sample TS delta from synch point
        sampleTimeAcc += lastSample->samples[i].sampleTime - toastBase;
        numSamples++;
      }
    }

    //convert sum of deltas from 32K to milliseconds
    sampleTimeAcc >>= 5;
    //divide sum of deltas by numSamples to get mean delta (ms)
    sampleTimeAcc /= numSamples; 
    //add the mean delta (ms) to the previously-stored bacon ms synch
    //point.
    sampleRec.baseTime += sampleTimeAcc;
    err = call LogWrite.append(&sampleRec, recordLen);
    if (err != SUCCESS){
      toastSampleIndex++;
      post nextSynch();
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
      post appendSample();
      return swp;
    }else{
      toastSampleIndex++;
      post nextSynch();
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
