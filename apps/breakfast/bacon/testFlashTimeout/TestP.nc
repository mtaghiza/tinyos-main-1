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

module TestP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface LogRead;
} implementation {
  
  uint8_t testRec[8] = { 0, 1, 2, 3, 4, 5, 6, 7};
  uint16_t appendLimit = 1000;
  
  event void Boot.booted(){
    call LogRead.seek(SEEK_BEGINNING);
  }

  task void appendTask(){
    printf("w %lu\n", call LogWrite.currentOffset());
    call LogWrite.append(testRec, 8);
  }

  event void LogRead.seekDone(error_t error){
    printf("Start %lu End %lu\n", 
      call LogRead.currentOffset(), 
      call LogWrite.currentOffset());
    post appendTask();
  }

  event void LogRead.readDone(void* buf, storage_len_t len, error_t
  error){
  }

  task void eraseTask(){
    call LogWrite.erase();
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){ 
    appendLimit --;
    if (appendLimit){
      post appendTask();
    }else{
      printf("Writes done: %lu\n", call LogWrite.currentOffset());
      post eraseTask();
    }
  }

  event void LogWrite.eraseDone(error_t error){
    printf("Erase done with timeout: %lu\n", 
      STM25P_SHUTDOWN_TIMEOUT);
    printfflush();
  }
  event void LogWrite.syncDone(error_t error){}

}
