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

#include "msp430_internal_capture.h"

generic module Msp430InternalCaptureP(){
  provides interface GpioCapture as Capture;
  uses interface Msp430TimerControl;
  uses interface Msp430Capture;

  uses interface GetNow<uint8_t> as GetCCIS;
} implementation {

  error_t enableCapture( uint8_t mode ) {
    atomic {
      msp430_compare_control_t ctrl;
      call Msp430TimerControl.disableEvents();
      call Msp430TimerControl.clearPendingInterrupt();
      call Msp430Capture.clearOverflow();
      //configure CCIS and CM bits, set to capture, leave the rest alone.
      ctrl = call Msp430TimerControl.getControl();
      ctrl.ccis = call GetCCIS.getNow();
      ctrl.cm = mode;
      ctrl.cap = 1;
      call Msp430TimerControl.setControl(ctrl);
      call Msp430TimerControl.enableEvents();
    }
    return SUCCESS;
  }

  async command error_t Capture.captureRisingEdge() {
    return enableCapture( MSP430TIMER_CM_RISING );
  }

  async command error_t Capture.captureFallingEdge() {
    return enableCapture( MSP430TIMER_CM_FALLING );
  }

  async command void Capture.disable() {
    atomic {
      call Msp430TimerControl.disableEvents();
    }
  }

  async event void Msp430Capture.captured( uint16_t time ) {
  //Is this supressing the compare interrupt? we just want to say "ok,
  //we got the capture." Surely this is wired to a different instance
  //from the alarms.
  // it appears to be suppressing it, that seems bad.
  //according to the user guide, the interrupt flag for capture events
  //is cleared automatically when the interrupt is serviced.
//    call Msp430TimerControl.clearPendingInterrupt();
    call Msp430Capture.clearOverflow();
    signal Capture.captured( time );
  }

}
