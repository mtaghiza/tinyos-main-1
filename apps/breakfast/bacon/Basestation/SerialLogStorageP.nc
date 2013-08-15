
 #include "SerialLogStorage.h"
generic module SerialLogStorageP(){
  provides interface LogWrite;
  uses interface AMSend;
  uses interface Pool<message_t>;
  uses interface Packet;
  uses interface AMPacket;
  uses interface ActiveMessageAddress;
  uses interface SettingsStorage;
} implementation {
  
  void* _buf;
  storage_len_t _len;
  
  command error_t LogWrite.append(void* buf, storage_len_t len){
    message_t* msg = call Pool.get();
    if (msg){
      log_record_data_msg_t* pl = call Packet.getPayload(msg,
        sizeof(log_record_data_msg_t));
      log_record_t* lr = (log_record_t*)(&pl->data[0]);
      error_t error;

      lr->cookie = call LogWrite.currentOffset();
      lr->length = len;
      memcpy(lr->data, buf, len);

      pl->length = sizeof(log_record_t) + lr->length;
      pl->nextCookie = lr->cookie + (lr->length + 1);
      call AMPacket.setSource(msg, call ActiveMessageAddress.amAddress());
      error = call AMSend.send(0, msg, sizeof(log_record_data_msg_t));
      if (error != SUCCESS){
        call Pool.put(msg);
      }else{
        _buf = buf;
        _len = len;
      }
      return error;
    } else {
      return ENOMEM;
    }
  }

  command storage_cookie_t LogWrite.currentOffset(){ 
    nx_uint32_t cookie;
    error_t error; 
    cookie = 0;
    error = call SettingsStorage.get(SS_KEY_SERIAL_LOG_STORAGE_COOKIE,
      &cookie, sizeof(cookie));
    return cookie; 
  }
  command error_t LogWrite.erase(){ return FAIL;}
  command error_t LogWrite.sync(){ return FAIL;}

  event void AMSend.sendDone(message_t* msg_, error_t error_){
    log_record_data_msg_t* pl = call Packet.getPayload(msg_,
      sizeof(log_record_data_msg_t));
    error_t error = call SettingsStorage.set(SS_KEY_SERIAL_LOG_STORAGE_COOKIE,
      &(pl->nextCookie), sizeof(pl->nextCookie));
    call Pool.put(msg_);
    signal LogWrite.appendDone(_buf, _len, FALSE, error);
  }
  async event void ActiveMessageAddress.changed(){ }
}
