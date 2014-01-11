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

#include "InternalFlash.h"
#include "I2CPersistentStorage.h"
#include "decodeError.h"
#include "I2CCom.h"

module I2CPersistentStorageP{
  uses interface I2CComSlave;
  uses interface InternalFlash;
} implementation {
  i2c_message_t msg_internal;
  norace i2c_message_t* msg = &msg_internal;
  
  i2c_message_t* swap(i2c_message_t* msg_){
    i2c_message_t* swp = msg;
    msg = msg_;
    return swp;
  }

  task void readTask(){
    error_t error;
    i2c_persistent_storage_t* payload =
      (i2c_persistent_storage_t*) call I2CComSlave.getPayload(msg);
    payload->cmd = I2C_STORAGE_RESPONSE_CMD;
    //last byte is version
    error = call InternalFlash.read(0, payload->data, IFLASH_SEGMENT_SIZE - 1);
    call I2CComSlave.unpause();
  }

  //we don't unpause the lower layer until the data is filled into
  //  msg, so it's fine to just return that and do the swap.
  async event i2c_message_t* I2CComSlave.slaveTXStart(i2c_message_t* msg_){
    return swap(msg_);
  }

  task void writeTask(){
    i2c_persistent_storage_t* payload =
      (i2c_persistent_storage_t*) call I2CComSlave.getPayload(msg);
    error_t error;
    error = call InternalFlash.write(0, payload->data, IFLASH_SEGMENT_SIZE - 1);
    call I2CComSlave.unpause();
  }

  async event i2c_message_t* I2CComSlave.received(i2c_message_t* msg_){ 
    i2c_persistent_storage_t* payload =
      (i2c_persistent_storage_t*) call I2CComSlave.getPayload(msg_);
    switch(payload->cmd){
      case I2C_STORAGE_WRITE_CMD:
        //do not let any other commands come in until we're done with
        //  this one.
        call I2CComSlave.pause();
        post writeTask();
        //we need to hang onto this buffer, since we're going to
        //  persist the data to flash. do a swap.
        return swap(msg_);
      case I2C_STORAGE_READ_CMD:
        call I2CComSlave.pause();
        post readTask();
        return msg_;
      default:
        printf("unknown command\n\r");
        return msg_;
    }
  }

}
