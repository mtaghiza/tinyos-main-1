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
      //set CCIS and CM bits, leave the rest alone.
      ctrl = call Msp430TimerControl.getControl();
      ctrl.ccis = call GetCCIS.getNow();
      ctrl.cm = mode;
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
    call Msp430TimerControl.clearPendingInterrupt();
    call Msp430Capture.clearOverflow();
    signal Capture.captured( time );
  }

}
