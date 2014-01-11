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


 #include "SettingsStorage.h"
module SettingsStorageConfiguratorP{
  uses interface SettingsStorage;

  uses interface Receive as SetReceive;

  uses interface AMPacket;

  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  uses interface Receive as GetReceive;
  uses interface AMSend as GetSend;
  uses interface Receive as ClearReceive;
  #else
  #endif

  uses interface Pool<message_t>;
} implementation {
  message_t* rmsg = NULL;
  settings_storage_msg_t* pl = NULL;

  message_t* smsg = NULL;
  

  message_t* swapRx(message_t* msg, void* payload){
    if (rmsg == NULL && smsg == NULL){
      message_t* ret = call Pool.get();
      if (ret){
        rmsg = msg;
        pl = (settings_storage_msg_t*) payload;
        return ret;
      }
    }
    //busy or nothing in pool, ignore.
    return msg;
  }
 
  task void setTask();
  event message_t* SetReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    message_t* ret = swapRx(msg, payload);
    if (ret != msg){
      post setTask();
    }
    return ret;
  }

  task void setTask(){
    //ugh: so these are coming in as nx_uint8_t, which should not
    //matter.
    call SettingsStorage.set(pl->key, (uint8_t*)&(pl->val), pl->len);
    //clean up resources used
    call Pool.put(rmsg);
    rmsg = NULL;
    pl = NULL;
  }
  
  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  task void getTask();
  event message_t* GetReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    message_t* ret = swapRx(msg, payload);
    if (ret != msg){
      post getTask();
    }
    return ret;
  }

  task void getTask(){
    smsg = call Pool.get();
    if (smsg){
      settings_storage_msg_t* spl = call GetSend.getPayload(smsg,
        sizeof(settings_storage_msg_t));
      if (spl){
        spl->key = pl->key;
        spl->len = pl->len;
        spl->error =  call SettingsStorage.get(spl->key, 
          (uint8_t*)&(spl->val), spl->len);
        call GetSend.send(call AMPacket.source(rmsg), 
          smsg, sizeof(settings_storage_msg_t));
      }
    }
  }

  event void GetSend.sendDone(message_t* msg, error_t error){
    call Pool.put(smsg);
    call Pool.put(rmsg);
    smsg = NULL;
    rmsg = NULL;
    pl = NULL;
  }

  task void clearTask();
  event message_t* ClearReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    message_t* ret = swapRx(msg, payload);
    if (ret != msg){
      post clearTask();
    }
    return ret;
  }

  task void clearTask(){
    call SettingsStorage.clear(pl->key);
    //clean up resources used
    call Pool.put(rmsg);
    rmsg = NULL;
    pl = NULL;
  }
  #else

  #endif

}
