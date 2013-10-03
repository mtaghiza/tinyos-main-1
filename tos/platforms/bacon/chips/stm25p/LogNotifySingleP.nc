generic module LogNotifySingleP(){
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;

  provides interface Init;
  uses interface Notify<uint8_t> as SubNotify;
} implementation {
//  enum {
//    S_FILLING = 0,
//    S_DRAINING = 1,
//  };
//  
//  uint8_t recordState = S_FILLING;
  uint16_t outstandingRecords = 0;

  void checkRecordState(bool repostOK);

  command uint16_t RecordsNotify.getOutstanding(){
    return outstandingRecords;
  }

  task void recordSendRequest(){
    signal RecordsNotify.sendRequested(outstandingRecords);
  }

  command error_t RecordsNotify.setHighThreshold(uint16_t thresh){
    return FAIL;
//    if (thresh >= recordLow){
//      recordHigh = thresh;
//      checkRecordState(FALSE);
//      return SUCCESS;
//    } else {
//      return EINVAL;
//    }
  }

  command error_t RecordsNotify.setLowThreshold(uint16_t thresh){
    return FAIL;
//    if (thresh <= recordHigh){
//      recordLow = thresh;
//      checkRecordState(FALSE);
//      return SUCCESS;
//    } else {
//      return EINVAL;
//    }
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
//    //just passed upper threshold: start draining
//    if (outstandingRecords >= recordHigh && recordState == S_FILLING){
//      recordState = S_DRAINING;
//    }
//    //just passed lower threshold: start filling
//    if (outstandingRecords < recordLow && recordState == S_DRAINING){
//      recordState = S_FILLING;
//    } 
//    if (outstandingRecords >= 1 && recordState == S_FILLING){
//      recordState = S_DRAINING;
//    }
//    if (outstandingRecords == 0 && recordState == S_DRAINING){
//      recordState = S_FILLING;
//    }
    
    if (outstandingRecords && repostOK){
      post recordSendRequest();
    }
  }

  event void SubNotify.notify(uint8_t bytesWritten){
    outstandingRecords += 1;
    //Only OK to request when the record count passes the threshold (1)
    checkRecordState(outstandingRecords == 1);
//    outstandingBytes += bytesWritten;
  }

  default event void RecordsNotify.sendRequested(uint16_t requested){}


}
