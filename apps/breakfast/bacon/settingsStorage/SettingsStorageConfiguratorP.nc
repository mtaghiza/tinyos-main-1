
#include "SettingsStorage.h"
module SettingsStorageConfiguratorP{
  uses interface SettingsStorage;

  uses interface Receive as SetReceive;

  uses interface Receive as GetReceive;
  uses interface AMSend as GetSend;

  uses interface AMPacket;

  uses interface Receive as ClearReceive;

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


}
