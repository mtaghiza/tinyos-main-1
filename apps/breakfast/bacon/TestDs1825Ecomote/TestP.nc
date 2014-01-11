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


#include "OneWire.h"

/**
 * See the description in the configuration file
 * @author David Moss
 */
module TestP {
  uses {
    interface Boot;
    interface Read<int16_t> as TemperatureCC;
    interface OneWireDeviceInstanceManager;
    
    interface Leds;
  }
}

implementation {

  // Temperature level indicator thresholds, in degrees celsius * 100
  enum {
    TEMP_LEVEL_0 = 0,     // 32 degrees F
    TEMP_LEVEL_1 = 2250,  // 70 degrees F
    TEMP_LEVEL_2 = 2500,  // 74 degrees F
    TEMP_LEVEL_3 = 2750,  // 78 degrees F
  };
  
  /***************** Tasks ****************/
  task void getTemp() {
    if (call TemperatureCC.read() != SUCCESS) {
      call Leds.set(6);
    }
  }
  
  /***************** Boot Events ****************/
  event void Boot.booted() {
    error_t error;
    
    error = call OneWireDeviceInstanceManager.refresh();
    
    if(error != SUCCESS) {
      call Leds.set(2);
      return;
    }
    
  }

  event void OneWireDeviceInstanceManager.refreshDone(error_t result, bool devicesChanged) {
    onewire_t id;
    if (result == SUCCESS) {
      id = call OneWireDeviceInstanceManager.getDevice(call OneWireDeviceInstanceManager.numDevices()-1);
      call OneWireDeviceInstanceManager.setDevice(id);
      post getTemp();
    }
    else {
      call Leds.set(4);
      return;
    }
  }

  /***************** Read Events ****************/
  event void TemperatureCC.readDone(error_t error, int16_t value) {
    int32_t temp_f;
    if (SUCCESS != error) {
      return;
    }
    temp_f = 3200 + (9 * value) / 5;
    
    call Leds.set(0);
    
    if(value > TEMP_LEVEL_1) {
      call Leds.led0On();
    }
    
    if(value > TEMP_LEVEL_2) {
      call Leds.led1On();
    }
    
    if(value > TEMP_LEVEL_3) {
      call Leds.led2On();
    }
    
    post getTemp();
  }
}
