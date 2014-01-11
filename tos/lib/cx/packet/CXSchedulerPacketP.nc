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


 #include "CXScheduler.h"
module CXSchedulerPacketP {
  provides interface Packet;
  provides interface CXSchedulerPacket;

  uses interface Packet as SubPacket;
  uses interface CXPacketMetadata;
} implementation {
  cx_schedule_header_t* getHeader(message_t* msg){
    return call SubPacket.getPayload(msg,
      sizeof(cx_schedule_header_t));
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
    getHeader(msg) -> sn = INVALID_SCHEDULE;
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_schedule_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_schedule_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() -
      sizeof(cx_schedule_header_t);
  }

  command void* Packet.getPayload(message_t* msg, 
      uint8_t len){
    void* pl = call SubPacket.getPayload(msg,
      len + sizeof(cx_schedule_header_t));
    if (pl){
      return pl + sizeof(cx_schedule_header_t);
    }else{
      return pl;
    }
  }

  command uint8_t CXSchedulerPacket.getScheduleNumber(message_t* msg){
    return getHeader(msg)->sn;
  }

  command void CXSchedulerPacket.setOriginFrame(message_t* msg,
      uint32_t originFrame){
    getHeader(msg)->originFrame = originFrame;
  }

  command uint32_t CXSchedulerPacket.getOriginFrame(message_t* msg){
    return getHeader(msg)->originFrame;
  }

  command void CXSchedulerPacket.setScheduleNumber(message_t* msg,
      uint8_t sn){
    getHeader(msg)->sn = sn;
  }

}
