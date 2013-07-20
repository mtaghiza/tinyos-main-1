generic module DummyLogWriteC(){
  provides interface LogWrite;
} implementation{
  task void signalAD(){
    signal LogWrite.appendDone(NULL, 0, FALSE, SUCCESS);
  }
  command error_t LogWrite.append(void* buf, storage_len_t len){
    post signalAD();
    return SUCCESS;
  }
  command error_t LogWrite.erase(){ return FAIL;}
  command error_t LogWrite.sync(){return FAIL;}
  command storage_cookie_t LogWrite.currentOffset(){return 0;}
}
