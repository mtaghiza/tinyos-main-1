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

module SimpleFloodSchedulerP{
  provides interface Send;
  provides interface Receive;

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Packet as AMPacketBody;

  uses interface TDMARoutingSchedule;

  provides interface CXTransportSchedule;
} implementation {
  enum {
    S_IDLE,
    S_PENDING,
    S_SENDING,
    S_CLEARING,
  };

  uint8_t state = S_IDLE;

  command error_t Send.send(message_t* msg, uint8_t len){
    if (state == S_IDLE){
      error_t error ;
      call CXPacketMetadata.setRequiresClear(msg, TRUE);
      call CXPacket.setTransportType(msg, CX_TYPE_DATA);
      error = call FloodSend.send(msg, len);
      if (error == SUCCESS){
        state = S_PENDING;
      }
      return error;
    }else{
      return EBUSY;
    }
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
    state = S_IDLE;
    signal Send.sendDone(msg, error);
  }

  command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched() && state == S_PENDING){
      if(call TDMARoutingSchedule.ownsFrame(frameNum)){
        state = S_SENDING;
        return TRUE;
      }else{
        return FALSE;
      }
    }else{
      return FALSE;
    }
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call AMPacketBody.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: might be necessary to restore AMPacket's destination field
    //(from CXPacket header)?
    return signal Receive.receive(msg,
      call AMPacketBody.getPayload(msg, 
        call AMPacketBody.payloadLength(msg)),
      call AMPacketBody.payloadLength(msg));
  }

}
