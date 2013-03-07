 #include "AM.h"
module TestP{
  uses interface Boot;
  provides interface Get<am_addr_t>;
  uses interface SplitControl;
} implementation {
  event void Boot.booted(){
    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
  
  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }
}
