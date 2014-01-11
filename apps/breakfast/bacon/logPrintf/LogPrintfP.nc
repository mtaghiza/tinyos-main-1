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

generic module LogPrintfP() {
  provides interface LogPrintf;
  uses interface LogWrite;
  uses interface Queue<log_printf_t*>;
  uses interface Pool<log_printf_t>;
} implementation {
  bool appending = FALSE;

  task void appendNext(){
    if (!appending && ! (call Queue.empty())){
      log_printf_t* rec = call Queue.dequeue();
      error_t error = call LogWrite.append(rec, 
        sizeof(rec->recordType) + rec->len);
      if (error == SUCCESS){
        appending = TRUE;
      }else{
        post appendNext();
      }
    }
  }

  command error_t LogPrintf.log(uint8_t* buf, uint8_t len){
    log_printf_t* rec = call Pool.get();
    if (rec != NULL){
      rec->recordType = RECORD_TYPE_LOG_PRINTF;
      rec->len = len;
      memcpy(rec->str, buf, len);
      call Queue.enqueue(rec);
      post appendNext();
      return SUCCESS;
    }else{
      return ENOMEM;
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
    appending = FALSE;
    if (buf != NULL){
      call Pool.put(buf);
    }
    post appendNext();
  }

  event void LogWrite.eraseDone(error_t error){ }
  event void LogWrite.syncDone(error_t error){ }

}
