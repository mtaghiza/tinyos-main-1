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

#include "GlobalID.h"
module AnalogSensorBoardP{
  uses interface Boot;
  uses interface SplitControl;
  uses interface GlobalID;
  uses interface I2CDiscoverable;
} implementation {
  uint8_t globalId[GLOBAL_ID_LEN];

  event void Boot.booted(){
    //TODO: check for lastLocalAddr in flash and call
    //  I2CDiscoverable.setLocalAddr before starting
    printf("booted\n\r");
    call SplitControl.start();
  }

  event uint8_t* I2CDiscoverable.getGlobalAddr(){
    call GlobalID.getID(globalId, GLOBAL_ID_LEN);
    return globalId;
  }

  event void SplitControl.startDone(error_t error){
    //cool
  }

  event void SplitControl.stopDone(error_t error){
  }

  event void I2CDiscoverable.assigned(error_t err, uint16_t lastLocalAddr){
    //TODO: persist lastLocalAddr to flash (replace previous)
  }

}
