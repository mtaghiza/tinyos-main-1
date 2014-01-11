/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


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
      error = call AMSend.send(0, msg, sizeof(log_record_data_msg_t) +
        pl->length);
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
