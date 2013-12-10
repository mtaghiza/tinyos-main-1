module DummySettingsStorageP{
  provides interface SettingsStorage;
  uses interface LogWrite;
} implementation {
  command error_t SettingsStorage.get(uint8_t key, void* val, uint8_t len){
    return EINVAL;
  }
  command error_t SettingsStorage.set(uint8_t key, void* val, uint8_t len){
    return SUCCESS;
  }
  command error_t SettingsStorage.clear(uint8_t key){
    return SUCCESS;
  }
  task void signalAD(){
  }

  default command error_t LogWrite.append(void* buf, storage_len_t len){
    return SUCCESS;
  }
  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){}
}
