
 #include "TestbedDebug.h"
 #include "testbed.h"
module TestbedRootP {
  uses interface CXDownload[uint8_t ns];
  uses interface Boot;
  uses interface SplitControl;
  uses interface Timer<TMilli>;
} implementation {
  event void Boot.booted(){
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
}
