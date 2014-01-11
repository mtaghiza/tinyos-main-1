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

 #include "BusPower.h"
module BusPowerC{ 
  //wired by clients
  provides interface SplitControl[uint8_t id];
  //wired by platform (e.g. controlling a voltage regulator, switch,
  // what-have-you)
  uses interface SplitControl as SubSplitControl;
} implementation {
  enum{
    FLAG_STOPPED = 0,
    FLAG_PENDING_START,
    FLAG_PENDING_STOP,
    FLAG_STARTED,
  };

  enum{
    S_OFF,
    S_STARTING,
    S_STOPPING,
    S_ON,
  };

  uint8_t activeCount = 0;
  uint8_t clientFlags[uniqueCount(UQ_BUS_POWER_CLIENT)];
  uint8_t state = S_OFF;
 
  task void clearStartFlags(){
    uint8_t k;
    for (k = 0; k < uniqueCount(UQ_BUS_POWER_CLIENT); k++){
      if (clientFlags[k] == FLAG_PENDING_START){
        clientFlags[k] = FLAG_STARTED;
        signal SplitControl.startDone[k](SUCCESS);
      }
    }
  }

  task void subStartTask(){
    call SubSplitControl.start();
  }

  command error_t SplitControl.start[uint8_t id](){
    atomic{
      if (clientFlags[id] == FLAG_STOPPED){
        clientFlags[id] = FLAG_PENDING_START;
        activeCount++;
      }else{
        return EALREADY;
      }

      if (activeCount == 1){
        state = S_STARTING;
        post subStartTask();
      } else if (state == S_ON){
        post clearStartFlags();
      }
    }
    return SUCCESS;
  }


  task void clearStopFlags(){ 
    uint8_t k;
    for (k = 0; k < uniqueCount(UQ_BUS_POWER_CLIENT); k++){
      if (clientFlags[k] == FLAG_PENDING_STOP){
        clientFlags[k] = FLAG_STOPPED;
        signal SplitControl.stopDone[k](SUCCESS);
      }
    }
  }

  task void subStopTask(){
    call SubSplitControl.stop();
  }

  command error_t SplitControl.stop[uint8_t id](){
    atomic{
      if (clientFlags[id] == FLAG_STARTED){
        clientFlags[id] = FLAG_PENDING_STOP;
        activeCount--;
      } else { 
        return EALREADY;
      }

      if (activeCount == 0){
        state = S_STOPPING;
        post subStopTask();
      } else if (state == S_OFF){
        post clearStopFlags();
      }
    }
    return SUCCESS;
  }

  event void SubSplitControl.startDone(error_t err){
    state = S_ON;
    post clearStartFlags();
  }

  event void SubSplitControl.stopDone(error_t err){
    state = S_OFF;
    post clearStopFlags();
  }
  
  default event void SplitControl.startDone[uint8_t id](error_t err){ }
  default event void SplitControl.stopDone[uint8_t id](error_t err){ }
}
