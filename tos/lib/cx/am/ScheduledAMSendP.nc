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

module ScheduledAMSendP {
  provides interface ScheduledAMSend[uint8_t clientId];
  uses interface AMSend as SubAMSend[uint8_t clientId];
  uses interface CXPacketMetadata;
} implementation {
  command error_t ScheduledAMSend.send[uint8_t clientId](am_addr_t addr, 
      message_t* msg, uint8_t len, uint32_t frameNum){
    call CXPacketMetadata.setRequestedFrame(msg, frameNum);
    return call SubAMSend.send[clientId](addr, msg, len);
  }

  command error_t ScheduledAMSend.cancel[uint8_t clientId](message_t* msg){
    return call SubAMSend.cancel[clientId](msg);
  }

  command uint8_t ScheduledAMSend.maxPayloadLength[uint8_t clientId](){
    return call SubAMSend.maxPayloadLength[clientId]();
  }

  command void* ScheduledAMSend.getPayload[uint8_t clientId](message_t* msg, uint8_t len){
    return call SubAMSend.getPayload[clientId](msg, len);
  }

  event void SubAMSend.sendDone[uint8_t clientId](message_t* msg,
      error_t error){
    call CXPacketMetadata.setRequestedFrame(msg, INVALID_FRAME);
    signal ScheduledAMSend.sendDone[clientId](msg, error);
  }

  default event void ScheduledAMSend.sendDone[uint8_t clientId](message_t* msg,
      error_t error){}

  default command error_t SubAMSend.send[uint8_t clientId](am_addr_t addr, 
      message_t* msg, uint8_t len){
    return FAIL;
  }
  default command error_t SubAMSend.cancel[uint8_t clientId](message_t* msg){
    return FAIL;
  }
  default command uint8_t SubAMSend.maxPayloadLength[uint8_t clientId](){
    return 0;
  }

  default command void* SubAMSend.getPayload[uint8_t clientId](message_t* msg, uint8_t len){
    return NULL;
  }

}
