module TestP{
  uses interface SplitControl;
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface LogWrite;
  provides interface Get<am_addr_t>;
} implementation {
  
  uint8_t testRec[15] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  uint8_t curLen = sizeof(testRec);
  uint16_t appendLimit = 0;
  
  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }

  event void Boot.booted(){
    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t error){
    printf("Booted\n");
    printfflush();
    call Timer.startOneShot(2048);
  } 

  event void Timer.fired(){
    
    if (-- appendLimit ){
      call LogWrite.append(testRec, curLen);
    }else{
      printf("Done\r\n");
      printfflush();
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){ 
    uint8_t i;

    curLen = (curLen == 5)? sizeof(testRec) : curLen-1;
//    printf("Append done.\n");

    for (i = 0; i < curLen; i++)
      testRec[i] = curLen;

    call Timer.startOneShot(100);
  }

  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}

  event void SplitControl.stopDone(error_t error){ }
}
