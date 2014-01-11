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

 #include "StateTimingDebug.h"
 #include "Msp430SWCapture.h"
 #include "Msp430Timer.h"
generic module Msp430SWCaptureP(){
  uses interface Msp430Timer;
  uses interface Msp430TimerControl;
  uses interface Msp430Capture;

  provides interface SWCapture;
  provides interface Init;
} implementation {
  norace uint32_t lastCapture = 0;
  norace uint32_t overflows = 0;

  command error_t Init.init(){
    msp430_compare_control_t ctrl;
    call Msp430TimerControl.disableEvents();
    ctrl = call Msp430TimerControl.getControl();
    ctrl.scs = 1;
    ctrl.ccis = CCIS_GND;
    ctrl.cm = MSP430TIMER_CM_BOTH;
    ctrl.cap = 1;
    ctrl.ccie = 0;
    call Msp430TimerControl.setControl(ctrl);
//    call Msp430TimerControl.enableEvents();
    return SUCCESS;
  }

  async command uint32_t SWCapture.capture(){
    msp430_compare_control_t ctrl = call Msp430TimerControl.getControl();
    uint32_t ret;
    uint32_t ot;
    uint32_t cap;
    uint16_t capOrig;
    bool pendingOverflow;
    //toggle the signal to generate a capture
//    if (ctrl.cci){
//      SW_CAP_CLEAR_PIN;
//      ctrl.ccis = CCIS_GND;
//    } else {
//      SW_CAP_SET_PIN;
//      ctrl.ccis = CCIS_VCC;
//    }
    ctrl.ccis = (ctrl.cci)? CCIS_GND:CCIS_VCC;
    //trigger it 
    call Msp430TimerControl.setControl(ctrl);
    //check for pending overflow
    pendingOverflow = call Msp430Timer.isOverflowPending(); 


    //if the trigger happened just before the overflow, try to detect
    //it and deal with it. Ideally it would latch the
    //overflow pending flag at the same time as it latched in the
    //timer value.
    //the threshold for this behavior comes from running it
    //on the testbed,setting the threshold to 0xffff, and adjusting
    //this down until I stop seeing the warning messages below.
    capOrig = call Msp430Capture.getEvent();
    pendingOverflow &= (capOrig < 0xfffb);

    ot = ((overflows + (pendingOverflow?1:0))* (0x00010000UL));
    cap = capOrig + ot;
    ret = cap - lastCapture;
    if ( (ret & 0xffff0000UL) == 0xffff0000UL){
      //despite our best efforts, it's possible that two captures are
      //taken in an atomic block on either side of an overflow
      //boundary.
      // we assume that there's never a gargantuan number of overflows
      // (periodic timer should enforce that this is the case under
      // normal conditions).
      printf_SW_CAPTURE("BIG: c %x o %lx p %x C %lx l %lx r %lx->", 
        capOrig, overflows, 
        pendingOverflow,
        cap,
        lastCapture, 
        ret);
      ret &= 0x0000ffff;
      printf_SW_CAPTURE("%lx\r\n", ret);
    }
    lastCapture = cap;
//    overflows = 0;
    return ret;
  }

  async event void Msp430Capture.captured( uint16_t time ) {
  }

  async event void Msp430Timer.overflow(){
    SW_OF_TOGGLE_PIN;
    //we should be clearing this, right? The other users of this Timer
    //don't seem to be doing anything with it?
    overflows++;
    call Msp430Timer.clearOverflow();
  }
}
