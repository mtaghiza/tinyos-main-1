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

module Apds9007P{
  provides interface SplitControl;
  uses interface GeneralIO as ShutdownPin;
} implementation {
  //TODO: DC-- to be completely correct, this should pass the read
  //  interfaces through, and return errors as appropriate if the
  //  sensor's off
  bool on=FALSE;

  task void startDoneTask(){
    signal SplitControl.startDone(SUCCESS);
  }

  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.start(){
    if (! on){
      call ShutdownPin.clr();
      on = TRUE;
      //TODO: delay for warmup
      post startDoneTask();
      return SUCCESS;
    } else {
      return EALREADY;
    }
  }

  command error_t SplitControl.stop(){
    if (on){
      call ShutdownPin.set();
      on = FALSE;
      post stopDoneTask();
      return SUCCESS;
    } else {
      return EALREADY;
    }
  }

  default event void SplitControl.startDone(error_t err){}
  default event void SplitControl.stopDone(error_t err){}
}
