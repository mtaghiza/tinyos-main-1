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

 #include "BaconBusPower.h"
module PlatformBusPowerP{
  provides interface Init;
  provides interface SplitControl;
  uses interface GeneralIO as EnablePin;
  uses interface GeneralIO as I2CData;
  uses interface GeneralIO as I2CClk;
  uses interface GeneralIO as Term1WB;
  uses interface Timer<TMilli>;
} implementation {
  bool on = FALSE;
  command error_t Init.init(){
    call Term1WB.makeOutput();
    call Term1WB.clr();
    call I2CData.makeOutput();
    call I2CData.clr();
    call I2CClk.makeOutput();
    call I2CClk.clr();
    call EnablePin.makeOutput();
    call EnablePin.clr();
    return SUCCESS;
  }

  task void startDoneTask(){
    signal SplitControl.startDone(SUCCESS);
  }
  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.start(){
    if (on){
      return EALREADY;
    }else {
      on = TRUE;
      call Term1WB.makeInput();
      //start powering up the bus over the I2C lines
      //This is a bit of a hack: if we just flip the switch from GND
      //to 3V0, the resulting rush of current browns out the cc430.
      call I2CData.set();
      call I2CClk.set();

      //Ideally, we'd wait until the input to Term1WB was high, but:
      // 1. if there's nothing connected to the bus, this might not
      //    ever happen
      // 2. There may still be a voltage difference of 1.5V when this
      //    occurs
      // So, we just wait some short period of time.
      call Timer.startOneShot(BUS_STARTUP_TIME);
      return SUCCESS;
    }
  }

  event void Timer.fired(){
    // bus should be ready now, flip the switch.
    call EnablePin.set();
    post startDoneTask();
  }

  command error_t SplitControl.stop(){
    if (on){
      on = FALSE;
      call I2CData.clr();
      call I2CClk.clr();
      call Term1WB.makeOutput();
      call Term1WB.clr();
      call EnablePin.clr();
      post stopDoneTask();
      return SUCCESS;
    } else {
      return EALREADY;
    }
  }

  default event void SplitControl.startDone(error_t err){}
  default event void SplitControl.stopDone(error_t err){}
}
