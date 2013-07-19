
 #include "SettingsStorage.h"
module SettingsStorageP {
  provides interface SettingsStorage;

  uses interface TLVStorage;
  uses interface TLVUtils;
  uses interface Boot;
  uses interface LogWrite;
  uses interface Get<uint16_t> as RebootCounter;
  uses interface LocalTime<TMilli>;
} implementation {

  //TODO: un-hardcode this. Should be based on some platform
  //TLVStorage len constant.
  uint8_t tlvs[128];
  bool loaded = FALSE;


  command error_t SettingsStorage.get(uint8_t key, void* val, uint8_t len){
    tlv_entry_t* entry;
    error_t ret = SUCCESS;
    if (! loaded){
      ret = call TLVStorage.loadTLVStorage(tlvs);
      loaded = TRUE;
    }
    if (ret == SUCCESS){
      uint8_t tlvi = call TLVUtils.findEntry(key, 0, &entry, tlvs);
      if (tlvi){
        if (entry->len == len){
          memcpy(val, &(entry->data), len);
          return SUCCESS;
        } else{
          return ESIZE;
        }
      }else{
        return EINVAL;
      }
    }else{
      return ret;
    }
  }
 
  settings_record_t rec = {.recordType=RECORD_TYPE_SETTINGS};
  bool logging;
  enum {
    S_IDLE=0x00,
    S_LOG_FIRST = 0x01,
    S_LOG_SECOND = 0x02,
  };
  uint8_t logState = S_IDLE;

  task void logSettings1(){
    if (logState == S_IDLE){
      if (! loaded){
        error_t error = call TLVStorage.loadTLVStorage(tlvs);
        if (error == SUCCESS){
          loaded = TRUE;
        }
      }
      if (loaded){
        logState = S_LOG_FIRST;
        rec.rebootCounter = call RebootCounter.get();
        rec.ts = call LocalTime.get();
        rec.offset = 0;
        memcpy(&rec.data, tlvs, SETTINGS_CHUNK_SIZE);
        if (SUCCESS == call LogWrite.append(&rec, sizeof(rec))){
          //cool
        }else {
          logState = S_IDLE;
        }
      }
    }
  }

  task void logSettings2(){
    if (logState == S_LOG_FIRST){
      logState = S_LOG_SECOND;
      rec.offset = SETTINGS_CHUNK_SIZE;
      memcpy(&rec.data, &tlvs[SETTINGS_CHUNK_SIZE], SETTINGS_CHUNK_SIZE);
      if (SUCCESS == call LogWrite.append(&rec, sizeof(rec))){
        //cool
      }else {
        logState = S_IDLE;
      }
    }else{
      //unexpected state
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
    if (error == SUCCESS){
      if (logState == S_LOG_FIRST){
        post logSettings2();
      }else {
        logState = S_IDLE;
      }
    } else {
      //ruh-roh
      logState = S_IDLE;
    }
  }

  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}
  
  event void Boot.booted(){
    post logSettings1();
  }

  command error_t SettingsStorage.set(uint8_t key, void* val, uint8_t len){
    tlv_entry_t* entry;
    error_t ret = SUCCESS;
    if (!loaded){
      ret = call TLVStorage.loadTLVStorage(tlvs);
      loaded = TRUE;
    }
    if (ret == SUCCESS){
      uint8_t tlvi = call TLVUtils.findEntry(key, 0, &entry, tlvs);
      if (tlvi){
        //entry is now pointing at either a new spot or an existing one
        memcpy(&(entry->data), val, len);
      } else {
        //addEntry uses somewhat different semantics: need to
        //give it a pointer to an already-filled-in tlv_entry_t
        //ugh.
        tlv_entry_t e;
        e.tag = key;
        e.len = len;
        memcpy(&(e.data), val, len);
        //not found? new entry.
        tlvi = call TLVUtils.addEntry(key, len, &e, tlvs, 0);
        if (! tlvi){
          //not enough space to add entry.
          return ESIZE;
        }
      }
      ret = call TLVStorage.persistTLVStorage(tlvs);
      if (ret == SUCCESS){
        loaded = FALSE;
        ret = call TLVStorage.loadTLVStorage(tlvs);
        if (ret == SUCCESS){
          loaded = TRUE;
        }
      } 
      post logSettings1();
      return ret;
    }else{
      return ret;
    }
  }

  command error_t SettingsStorage.clear(uint8_t key){
    tlv_entry_t* entry;
    error_t ret = call TLVStorage.loadTLVStorage(tlvs);
    if (ret == SUCCESS){
      uint8_t tlvi = call TLVUtils.findEntry(key, 0, &entry, tlvs);
      if (! tlvi){
        return EINVAL;
      }else{
        ret = call TLVUtils.deleteEntry(tlvi, tlvs);
        post logSettings1();
        if (ret == SUCCESS){
          return call TLVStorage.persistTLVStorage(tlvs);
        }else{
          return ret;
        }
      }
    } else {
      return ret;
    }
  }
}
