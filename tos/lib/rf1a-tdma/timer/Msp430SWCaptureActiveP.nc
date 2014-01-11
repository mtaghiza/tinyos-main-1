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


 #include "Msp430SWCapture.h"
 #include "Msp430Timer.h"
generic module Msp430SWCaptureP(){
  uses interface Msp430Timer;
  uses interface Msp430TimerControl;
  uses interface Msp430Capture;

  provides interface SWCapture;
  provides interface Init;
} implementation {
  norace uint32_t activeTime = 0;
  norace uint16_t activeStart;
  norace uint16_t timerOverflows = 0;

  command error_t Init.init(){
    msp430_compare_control_t ctrl;
    call Msp430TimerControl.disableEvents();
    ctrl = call Msp430TimerControl.getControl();
    ctrl.scs = 1;
    ctrl.ccis = CCIS_GND;
    ctrl.cm = MSP430TIMER_CM_BOTH;
    ctrl.cap = 1;
    call Msp430TimerControl.setControl(ctrl);
    call Msp430TimerControl.enableEvents();
    return SUCCESS;
  }

  async command error_t SWCapture.active(){
    msp430_compare_control_t ctrl = call Msp430TimerControl.getControl();
    if (ctrl.cci == 1){
      return EALREADY;
    }else {
      ctrl.ccis = CCIS_VCC;
      timerOverflows = 0;
      call Msp430TimerControl.setControl(ctrl);
      return SUCCESS;
    }
  }

  async event void Msp430Capture.captured( uint16_t time ) {
    msp430_compare_control_t ctrl;
    if ( call Msp430Capture.isOverflowPending()){
      //TODO: deal with this case. throw it out?
      printf("!SWC");
      call Msp430Capture.clearOverflow();
    }
    ctrl = call Msp430TimerControl.getControl();
    if (ctrl.cci == 0){
      activeTime += ((timerOverflows * 0x00010000) + time ) - activeStart;
    }else{
      activeStart = time;
    }
    call Msp430TimerControl.clearPendingInterrupt();
  }

  async command error_t SWCapture.inactive(){
    msp430_compare_control_t ctrl = call Msp430TimerControl.getControl();
    if (ctrl.cci  == 0){
      return EALREADY;
    } else {
      ctrl.ccis = CCIS_GND;
      call Msp430TimerControl.setControl(ctrl);
      return SUCCESS;
    }
  }

  async command uint32_t SWCapture.getActive(){
    return activeTime;
  }

  async event void Msp430Timer.overflow(){
    //we should be clearing this, right? The other users of this Timer
    //don't seem to be doing anything with it?
    call Msp430Timer.clearOverflow();
    timerOverflows++;
  }
}
