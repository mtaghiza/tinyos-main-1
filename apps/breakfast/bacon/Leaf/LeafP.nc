
 #include "AM.h"
module LeafP{
  uses interface Boot;
  uses interface SplitControl;
  provides interface Get<am_addr_t>;
} implementation {

  event void Boot.booted(){
    call SplitControl.start();
  }

  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
}
