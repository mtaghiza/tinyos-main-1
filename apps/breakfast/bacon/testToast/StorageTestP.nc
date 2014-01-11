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

#include "I2CCom.h"
#include "I2CPersistentStorage.h"
module StorageTestP{
  uses interface UartStream;
  uses interface Get<test_state_t*>;
  uses interface I2CPersistentStorageMaster;
  provides interface Get<const char*> as GetDesc;
} implementation {
  const char* testDesc = "Persistent Storage\n\r r: read\n\r w: write";
  i2c_message_t msg;

  command const char* GetDesc.get(){
    return testDesc;
  }

  task void readPersistentStorage(){
    error_t error;
    test_state_t* state = call Get.get();
    if (state->slaveCount == 0){
      printf("No slaves found yet ('d' to discover)\n\r");
    } else {
      printf("Reading from local addr %x\n\r", state->slaves[state->currentSlave]);
      error = call I2CPersistentStorageMaster.read(state->slaves[state->currentSlave], &msg);
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }
  event void I2CPersistentStorageMaster.readDone(error_t error,
      i2c_message_t* msg_){
    uint8_t i;
    void* buf = call I2CPersistentStorageMaster.getPayload(msg_);
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    if (error == SUCCESS){
      for (i = 0; i < 63; i++){
        if ( i % 8 == 0){
          printf("\n\r [%x]",i);
        }
        printf("\t%x", ((uint8_t*)buf)[i]);
      }
    }
    printf("\n\r");
  }

  task void writePersistentStorage(){
    error_t error;
    test_state_t* state = call Get.get();
    uint8_t* payload = (uint8_t*)call I2CPersistentStorageMaster.getPayload(&msg);
    uint8_t i;
    if (state->slaveCount == 0){
      printf("No slaves found yet ('d' to discover)\n\r");
    } else {
      for (i = 0; i < sizeof(i2c_persistent_storage_t)-1; i++){
        payload[i] = i;
      }
      printf("writing to local addr %x\n\r", state->slaves[state->currentSlave]);
      error = call I2CPersistentStorageMaster.write(state->slaves[state->currentSlave], &msg);
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }

  event void I2CPersistentStorageMaster.writeDone(error_t error,
      i2c_message_t* msg_){
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }


  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'r':
        post readPersistentStorage();
        break;
      case 'w':
        post writePersistentStorage();
        break;
      default:
        printf("%c", byte);
    }
  }

  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
}
