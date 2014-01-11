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


 #include "BaconSampler.h"
module BaconSamplerHighP {
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;

  uses interface StdControl as BatteryControl;
  uses interface Read<uint16_t> as BatteryRead;

  uses interface StdControl as LightControl;
  uses interface Read<uint16_t> as LightRead;

  uses interface SettingsStorage;
} implementation {
  nx_uint32_t sampleInterval = DEFAULT_SAMPLE_INTERVAL;
  bacon_sample_t sampleRec = {
    .recordType = RECORD_TYPE_BACON_SAMPLE,
    .rebootCounter = 0,
    .baseTime = 0,
    .battery = 0,
    .light = 0
  };

  event void Boot.booted(){
    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    call Timer.startPeriodic(sampleInterval);
  }

  task void readBattery();
  task void readLight();
  task void append();

  event void Timer.fired(){
    sampleRec.baseTime = call Timer.getNow();
    sampleRec.battery = 0x0000;
    sampleRec.light = 0x0000;
    
    post readBattery();
  }

  task void readBattery(){
    error_t error = call BatteryControl.start();
    if (error == SUCCESS){
      error = call BatteryRead.read();
    }

    if (error != SUCCESS){
      call BatteryControl.stop();
      post readLight();
    }
  }

  event void BatteryRead.readDone(error_t error, uint16_t val){
    if (error == SUCCESS){
      sampleRec.battery = val;
    }
    call BatteryControl.stop();
    post readLight();
  }


  task void readLight(){
    error_t error = call LightControl.start();
    if (error == SUCCESS){
        error = call LightRead.read();
    }else{
    }
    if (error != SUCCESS){
      call LightControl.stop();
      post append();
    }
  }

  event void LightRead.readDone(error_t error, uint16_t val){
    if (error == SUCCESS){
      sampleRec.light = val;
    }
    call LightControl.stop();
    post append();
  }

  task void append(){
    call LogWrite.append(&sampleRec, sizeof(sampleRec));
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsMaybeLost, error_t error){}
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.eraseDone(error_t error){}


}
