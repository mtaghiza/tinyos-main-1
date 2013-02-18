module SettingsStorageP {
  provides interface SettingsStorage;

  uses interface TLVStorage;
  uses interface TLVUtils;
} implementation {

  //TODO: un-hardcode this. Should be based on some platform
  //TLVStorage len constant.
  uint8_t tlvs[128];

  command error_t SettingsStorage.get(uint8_t key, uint8_t* val, uint8_t len){
    tlv_entry_t* entry;
    error_t ret = call TLVStorage.loadTLVStorage(tlvs);
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

  command error_t SettingsStorage.set(uint8_t key, uint8_t* val, uint8_t len){
    tlv_entry_t* entry;
    error_t ret = call TLVStorage.loadTLVStorage(tlvs);
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
      return call TLVStorage.persistTLVStorage(tlvs);
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
