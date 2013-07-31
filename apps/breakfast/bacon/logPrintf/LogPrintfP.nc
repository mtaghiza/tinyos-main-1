generic module LogPrintfP() {
  provides interface LogPrintf;
  uses interface LogWrite;
  uses interface Queue<log_printf_t*>;
  uses interface Pool<log_printf_t>;
} implementation {
  bool appending = FALSE;

  task void appendNext(){
    if (!appending && ! (call Queue.empty())){
      log_printf_t* rec = call Queue.dequeue();
      error_t error = call LogWrite.append(rec, 
        sizeof(rec->recordType) + rec->len);
      if (error == SUCCESS){
        appending = TRUE;
      }else{
        post appendNext();
      }
    }
  }

  command error_t LogPrintf.log(uint8_t* buf, uint8_t len){
    log_printf_t* rec = call Pool.get();
    if (rec != NULL){
      rec->recordType = RECORD_TYPE_LOG_PRINTF;
      rec->len = len;
      memcpy(rec->str, buf, len);
      call Queue.enqueue(rec);
      post appendNext();
      return SUCCESS;
    }else{
      return ENOMEM;
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
    appending = FALSE;
    if (buf != NULL){
      call Pool.put(buf);
    }
    post appendNext();
  }

  event void LogWrite.eraseDone(error_t error){ }
  event void LogWrite.syncDone(error_t error){ }

}
