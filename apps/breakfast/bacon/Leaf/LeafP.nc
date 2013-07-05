
 #include "AM.h"
module LeafP{
  uses interface Boot;
  uses interface SplitControl;
  provides interface Get<am_addr_t>;
} implementation {

  event void Boot.booted(){
    call SplitControl.start();
    #ifdef CC430_PIN_DEBUG
    atomic{
      //map SFD to 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
    }
    #endif
  }

  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
}
