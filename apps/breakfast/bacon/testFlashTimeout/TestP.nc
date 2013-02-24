module TestP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface LogRead;
} implementation {
  
  uint8_t testRec[8] = { 0, 1, 2, 3, 4, 5, 6, 7};
  uint16_t appendLimit = 1000;
  
  event void Boot.booted(){
    call LogRead.seek(SEEK_BEGINNING);
  }

  task void appendTask(){
    printf("w %lu\n", call LogWrite.currentOffset());
    call LogWrite.append(testRec, 8);
  }

  event void LogRead.seekDone(error_t error){
    printf("Start %lu End %lu\n", 
      call LogRead.currentOffset(), 
      call LogWrite.currentOffset());
    post appendTask();
  }

  event void LogRead.readDone(void* buf, storage_len_t len, error_t
  error){
  }

  task void eraseTask(){
    call LogWrite.erase();
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){ 
    appendLimit --;
    if (appendLimit){
      post appendTask();
    }else{
      printf("Writes done: %lu\n", call LogWrite.currentOffset());
      post eraseTask();
    }
  }

  event void LogWrite.eraseDone(error_t error){
    printf("Erase done with timeout: %lu\n", 
      STM25P_SHUTDOWN_TIMEOUT);
    printfflush();
  }
  event void LogWrite.syncDone(error_t error){}

}
