 #include "AM.h"
module TestP{
  uses interface Boot;
  provides interface Get<am_addr_t>;
  uses interface SplitControl;
  uses interface Msp430XV2ClockControl;
} implementation {
  event void Boot.booted(){
    call Msp430XV2ClockControl.stopMicroTimer();
//    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
  
  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }
}
