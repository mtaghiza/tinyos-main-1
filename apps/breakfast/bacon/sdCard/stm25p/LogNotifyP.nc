generic module LogNotifyP(){
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;

  provides interface Init;
  uses interface Notify<uint8_t> as SubNotify;
} implementation {
  enum {
    S_FILLING = 0,
    S_DRAINING = 1,
  };
  
  uint8_t recordState = S_FILLING;
  uint16_t outstandingRecords = 0;
  uint16_t recordLow = 1;
  uint16_t recordHigh = 0xFFFF;
//  uint16_t outstandingBytes = 0;

  void checkRecordState(bool repostOK);

  task void recordSendRequest(){
    signal RecordsNotify.sendRequested(outstandingRecords);
  }

  command error_t RecordsNotify.setHighThreshold(uint16_t thresh){
    if (thresh >= recordLow){
      recordHigh = thresh;
      checkRecordState(FALSE);
      return SUCCESS;
    } else {
      return EINVAL;
    }
  }

  command error_t RecordsNotify.setLowThreshold(uint16_t thresh){
    if (thresh <= recordHigh){
      recordLow = thresh;
      checkRecordState(FALSE);
      return SUCCESS;
    } else {
      return EINVAL;
    }
  }

  command error_t RecordsNotify.reportSent(uint16_t sent){
    if (sent <= outstandingRecords){
      outstandingRecords -= sent;
      checkRecordState(TRUE);
      return SUCCESS;
    }else{
      outstandingRecords = 0;
      return EINVAL;
    }
  }

  command void RecordsNotify.forceFlushed(){
    outstandingRecords = 0;
    checkRecordState(FALSE);
  }

  command error_t Init.init(){
    return call SubNotify.enable();
  }
  
  void checkRecordState(bool repostOK){
    //just passed upper threshold: start draining
    if (outstandingRecords >= recordHigh && recordState == S_FILLING){
      recordState = S_DRAINING;
    }
    //just passed lower threshold: start filling
    if (outstandingRecords < recordLow && recordState == S_DRAINING){
      recordState = S_FILLING;
    } 
    
    if (recordState == S_DRAINING){ // && repostOK){
      post recordSendRequest();
    }
  }

  event void SubNotify.notify(uint8_t bytesWritten){
    outstandingRecords += 1;
    checkRecordState((outstandingRecords == recordHigh));
//    outstandingBytes += bytesWritten;
  }

  default event void RecordsNotify.sendRequested(uint16_t requested){}


}
