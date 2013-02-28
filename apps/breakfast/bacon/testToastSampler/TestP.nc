 #include "AM.h"
module TestP{
  uses interface Boot;
  provides interface Get<am_addr_t>;
} implementation {
  event void Boot.booted(){
  }
  
  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }
}
