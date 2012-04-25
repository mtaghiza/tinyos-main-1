module SDLoggerRawP{
  provides interface SDLogger;
  provides interface SplitControl as WriteControl;
  uses interface Resource;
  uses interface SDCard;

  uses interface Boot;

} implementation {
  bool writing = FALSE;
  uint32_t addr;

  #ifndef SD_BUFFER_LEN
  #define SD_BUFFER_LEN 544
  #endif

  #ifndef FLUSH_THRESHOLD
  #define FLUSH_THRESHOLD 512
  #endif

  uint16_t recordBuffer_a[SD_BUFFER_LEN];
  uint16_t recordBuffer_b[SD_BUFFER_LEN];
  uint16_t* curBuffer = recordBuffer_a;
  uint16_t* lastBuffer = recordBuffer_b;

  uint16_t bufIndex = 0;

  event void Boot.booted(){
  }

  command error_t SDLogger.writeRecords(uint16_t* buffer, uint8_t recordCount){
    //space in current buffer, so go for it.
    if (recordCount + bufIndex < SD_BUFFER_LEN){
      uint8_t i;
      for (i = 0; i < recordCount; i++){
        curBuffer[bufIndex+i] = buffer[i];
      }
      bufIndex += recordCount;
      //if it's over the threshold, flush it and switch to the other
      //buffer
      if ( (bufIndex >= FLUSH_THRESHOLD) && (!writing)){
        error_t error = call SDCard.write(addr, (uint8_t*)curBuffer, sizeof(uint16_t) * bufIndex);
//        printf("FLUSH (%lu)\r\n", addr);
        if (error == SUCCESS){
          uint16_t* swp = lastBuffer;
          lastBuffer = curBuffer;
          curBuffer = swp;
          bufIndex = 0;
        }
//        printf("write error %lu %p %u %s\r\n", addr, curBuffer,
//          (sizeof(uint16_t))*bufIndex, decodeError(error));
        return error;
      }
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }

  command error_t WriteControl.start(){
    return (call Resource.request());
  }

  event void Resource.granted(){
    addr = 0;
    signal WriteControl.startDone(SUCCESS);
  }

  command error_t WriteControl.stop(){
    error_t error = call Resource.release(); 
    return error;
  }

  event void SDCard.writeDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
    if (error == SUCCESS){
      addr += count;
      writing = FALSE;
//      printf("wrote %u @ %lu\r\n", count, addr_);
    }else{
      printf("WD Error: %s\r\n", decodeError(error));
    }
  }

  event void SDCard.readDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
    printf("SDCard read done\n\r");
  }


}
