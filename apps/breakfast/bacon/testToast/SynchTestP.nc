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

#include "I2CSynch.h"
#include "decodeError.h"

module SynchTestP{
  uses interface UartStream;
  uses interface Get<test_state_t*>;
  uses interface I2CSynchMaster;
  provides interface Get<const char*> as GetDesc;
} implementation {
  const char* testDesc = "Synch\n\r r: read\n\r p: print\n\r R: reset\n\r";
  command const char* GetDesc.get(){
    return testDesc;
  }

  enum{
    SYNCH_COUNT = 10,
  };

  uint32_t locals[SYNCH_COUNT];
  uint32_t remotes[SYNCH_COUNT];
  norace uint8_t count;

  task void read(){
    test_state_t* state = call Get.get();
    error_t error;
    if (state->slaveCount == 0){
      printf("No slaves found yet ('d' to discover)\n\r");
    }else{
      error = call I2CSynchMaster.synch(state->slaves[state->currentSlave]);
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }

  event void I2CSynchMaster.synchDone(error_t error, uint16_t slaveAddr, synch_tuple_t result){
    printf("error: %s (local, remote): (%lu, %lu) \n\r", decodeError(error), result.localTime, result.remoteTime);
    locals[count%SYNCH_COUNT] = result.localTime;
    remotes[count%SYNCH_COUNT] = result.remoteTime;
    count++;
  }

  task void print(){
    int8_t i;
    printf("tuples = [");
    for (i = 0; i < count; i++){
      printf(" (%lu, %lu)", locals[i], remotes[i]);
      if (i < count-1){
        printf(", ");
      }
    }
    printf("]\n\r");
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'R':
        count = 0;
        break;
      case 'r':
        post read();
        break;
      case 'p':
        post print();
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
