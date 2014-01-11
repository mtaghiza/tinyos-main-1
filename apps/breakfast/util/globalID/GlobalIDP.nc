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

#include "GlobalID.h"
#include "PlatformTLVStorage.h"

module GlobalIDP{
  provides interface GlobalID;
  uses interface TLVStorage;
  uses interface TLVUtils;
} implementation {
  command error_t GlobalID.getID(uint8_t* idBuf, uint8_t maxLen){
    if (maxLen < GLOBAL_ID_LEN){
      return ESIZE;
    } else {
      global_id_entry_t* gid;
      uint8_t ba[PLATFORM_TLV_LEN];
      error_t err;
      err = call TLVStorage.loadTLVStorage(ba);
      if (err != SUCCESS){
        return err;
      }
      call TLVUtils.findEntry(TAG_GLOBAL_ID, 0, (tlv_entry_t**)&gid, ba);
      if (gid != NULL){
        memcpy(idBuf, gid->id, GLOBAL_ID_LEN);
        return SUCCESS;
      } else {
        return FAIL;
      }
    }
  }

  command uint8_t GlobalID.getIDLen(){
    return GLOBAL_ID_LEN;
  }

  command error_t GlobalID.setID(uint8_t* idBuf, uint8_t len){
    global_id_entry_t gid;
    tlv_entry_t* previous;
    uint8_t offset;
    uint8_t ba[PLATFORM_TLV_LEN];
    error_t err;
    if (len > GLOBAL_ID_LEN){
      return ESIZE;
    }
    memcpy(gid.id, idBuf, len);
    err = call TLVStorage.loadTLVStorage(ba);
    if (err != SUCCESS){
      return err;
    }
    offset = call TLVUtils.findEntry(TAG_GLOBAL_ID, 0, &previous,
      ba);
    if (previous != NULL){
      err = call TLVUtils.deleteEntry(offset, ba);
      if (SUCCESS != err){
        return err;
      }
    }
    offset = call TLVUtils.addEntry(TAG_GLOBAL_ID, len, (tlv_entry_t*)&gid, 
      ba, 0);
    if (offset != 0){
      return call TLVStorage.persistTLVStorage(ba);
    } else {
      return FAIL;
    }
  }

}
