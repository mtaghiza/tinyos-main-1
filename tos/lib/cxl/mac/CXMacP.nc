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


 #include "CXMac.h"
 #include "CXMacDebug.h"
module CXMacP{
  provides interface Send;
  uses interface Send as SubSend;
  uses interface CXMacController;
  uses interface Timer<TMilli>;
} implementation {
  
  message_t* pendingMsg = NULL;
  bool sendStarted = FALSE;
  uint8_t pendingLen;
  uint8_t retryCount;

  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg){
      cdbg(MAC, "CXMP.s.s BUSY\r\n");
      return EBUSY;
    }else{
      error_t e = call CXMacController.requestSend(msg);
      if (e == SUCCESS){
        retryCount = 0;
        pendingMsg = msg;
        pendingLen = len;
      }
      return e;
    }
  }

  event void Timer.fired(){
    signal CXMacController.requestGranted();
  }

  event void CXMacController.requestGranted(){
    if (pendingMsg){
      error_t error = call SubSend.send(pendingMsg, pendingLen);
      if (error == ERETRY || error == EBUSY){
        cdbg(MAC, "mretry %u\r\n", retryCount);
        retryCount ++;
        if (retryCount <= MAC_RETRY_LIMIT){
          call Timer.startOneShot(128UL);
          return;
        }
      }
      if (error != SUCCESS){
        message_t* msg = pendingMsg;
        pendingMsg = NULL;
        signal Send.sendDone(msg, error);
      }else{
        sendStarted = TRUE;
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    sendStarted = FALSE;
    pendingMsg = NULL;
    signal Send.sendDone(msg, error);
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call SubSend.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call SubSend.maxPayloadLength();
  }
  command error_t Send.cancel(message_t* msg){
    if (msg == pendingMsg){
      if (!sendStarted){
        pendingMsg = NULL;
        return SUCCESS;
      } else {
        error_t error = call SubSend.cancel(msg);
        if (error == SUCCESS){
          pendingMsg = NULL;
          sendStarted = FALSE;
        }
        return error;
      }
    } else {
      return FAIL;
    }
  }

}
