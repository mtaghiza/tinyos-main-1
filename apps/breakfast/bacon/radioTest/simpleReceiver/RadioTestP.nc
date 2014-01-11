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

#include "RadioTest.h"

module RadioTestP {
  uses{
    interface Boot;
    interface Leds;
    interface Receive;
    interface SplitControl as RadioSplitControl;
    interface Timer<TMilli> as AliveTimer;
  }
} implementation {
  enum {
    S_OFF = 0x00,
    S_ON = 0x01,
    S_IDLE = 0x02,
    S_ERR = 0x07,
    S_MAX = 0x10,
  };

  uint8_t state;
  uint16_t count = 0;
 
  void setState(uint8_t newState) {
    if (state < S_ERR ){
      state = newState;
    } else {
      //ignore, already in error state
    }
  }
  event void AliveTimer.fired() {
    call Leds.led0Toggle();
  }

  event void Boot.booted() {
    call RadioSplitControl.start();
  }

  event void RadioSplitControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call AliveTimer.startPeriodic(5000);
    } else {
      setState(S_ERR);
    }
  }

  event void RadioSplitControl.stopDone(error_t err) {
    setState(S_OFF);
  }
 
  event message_t* Receive.receive(message_t* msg, void* payload, error_t err) {
    count ++;
    if (count % 10){
      call Leds.led1Toggle();
    }
    call Leds.led2Toggle();
    return msg;
  }
  
}
