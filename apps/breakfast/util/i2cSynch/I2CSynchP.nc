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

#include "I2CCom.h"
#include "I2CSynch.h"

module I2CSynchP{
  uses interface LocalTime<T32khz>;
  uses interface I2CComSlave;
} implementation {

  async event i2c_message_t* I2CComSlave.slaveTXStart(i2c_message_t* msg_){
    synch_response_t* response;
    uint32_t localTime = call LocalTime.get();
    response = (synch_response_t*)call I2CComSlave.getPayload(msg_);
    //oscillator fault detected
    if (BCSCTL3 & LFXT1OF){
      response -> remoteTime = 0;
      response -> fault = 1;
    } else {
      response -> remoteTime = localTime;
      response -> fault = 0;
    }
    return msg_;
  }

  task void stabilizeAclk(){
    uint16_t counter = 0xff;
    //wait a while if there's an oscillator fault detected.
    while (counter > 0 && BCSCTL3 & LFXT1OF){
      counter --;
    }
    call I2CComSlave.unpause();
  }

  async event i2c_message_t* I2CComSlave.received(i2c_message_t* msg_){
    synch_message_t* pl = (synch_message_t*) call I2CComSlave.getPayload(msg_);
    switch (pl->cmd){
      case SYNCH_CMD_READY:
        call I2CComSlave.pause();
        post stabilizeAclk();
        break;
      default:
        break;
    }
    return msg_;
  }
}
