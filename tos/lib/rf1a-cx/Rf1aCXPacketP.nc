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

#include "CX.h"

module Rf1aCXPacketP{
  provides interface CXPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  uses interface Ieee154Packet;
  uses interface ActiveMessageAddress;
} implementation {

  cx_header_t* getHeader(message_t* msg){
    return (cx_header_t*)(call SubPacket.getPayload(msg, sizeof(cx_header_t)));
  }

  command void Packet.clear(message_t* msg) {
    call SubPacket.clear(msg);
    //TODO: reset anything germane to this header
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    //TODO: double-check: shouldn't need to do anything here.
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return (void*) (sizeof(cx_header_t) + (call SubPacket.getPayload(msg,
        len+sizeof(cx_header_t))));
    } else {
      return 0;
    }
  }

  command am_addr_t CXPacket.destination(message_t* amsg){
    return getHeader(amsg)->destination;
  }

  command void CXPacket.setDestination(message_t* amsg, am_addr_t addr){
    getHeader(amsg)->destination = addr;
  }

  command am_addr_t CXPacket.source(message_t* amsg){
    return call Ieee154Packet.source(amsg);
  }
  command void CXPacket.setSource(message_t* amsg, am_addr_t addr){
    call Ieee154Packet.setSource(amsg, addr);
  }

  //argh why doesn't ieee154packet expose this?
  command uint8_t CXPacket.sn(message_t* amsg){
    return getHeader(amsg)->sn;
  }

  command void CXPacket.setSn(message_t* amsg, uint8_t cxsn){
    getHeader(amsg)->sn = cxsn;
  }

  command uint8_t CXPacket.count(message_t* amsg){
    return getHeader(amsg)->count;
  }

  command void CXPacket.setCount(message_t* amsg, uint8_t cxcount){
    getHeader(amsg)->count = cxcount;
  }


  command bool CXPacket.isForMe(message_t* amsg){
    return (call CXPacket.destination(amsg) == call
    ActiveMessageAddress.amAddress() ||
            call CXPacket.destination(amsg) == AM_BROADCAST_ADDR);
  }

  command am_id_t CXPacket.type(message_t* amsg){
    return getHeader(amsg)->type;
  }
  command void CXPacket.setType(message_t* amsg, am_id_t t){
    getHeader(amsg)->type = t;
  }

  async event void ActiveMessageAddress.changed(){ }
}
