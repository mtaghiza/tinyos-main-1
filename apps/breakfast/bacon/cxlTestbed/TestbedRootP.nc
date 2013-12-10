
 #include "TestbedDebug.h"
 #include "testbed.h"
module TestbedRootP {
  uses interface CXDownload[uint8_t ns];
  uses interface Boot;
  uses interface SplitControl;
  uses interface Timer<TMilli>;
} implementation {
  event void Boot.booted(){
    #ifndef CC430_PIN_DEBUG
    #define CC430_PIN_DEBUG 0
    #endif
    #if CC430_PIN_DEBUG == 1
    atomic{
      uint8_t i;
      //map SFD to 2.4
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
      
      //clear p1.1, use as gpio
      P1SEL &= ~BIT1;
      P1DIR |=  BIT1;
      P1OUT &= ~BIT1;

//      for (i=0 ; i < 10; i++){
//        P1OUT ^=BIT1;
//      }
    }
    #endif
    cinfo(TESTBED, "ROOT START\r\n");
    call SplitControl.start();
  }
  
  event void SplitControl.startDone(error_t error){
    call Timer.startOneShot(STARTUP_DELAY);
  }

  event void Timer.fired(){
    error_t error = call CXDownload.startDownload[TEST_SEGMENT](); 
    if (error != SUCCESS){
      cerror(TESTBED, "DOWNLOAD %x\r\n", error);
    }
  }

  event void CXDownload.downloadFinished[uint8_t ns](){
    call Timer.startOneShot(TEST_DELAY);
  }

  event void SplitControl.stopDone(error_t error){ }
  default command error_t CXDownload.startDownload[uint8_t ns](){
    return FAIL;
  }

  event void CXDownload.eos[uint8_t ns](am_addr_t owner, eos_status_t status){}
}
