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


 #include "CXAM.h"
module CXAMPacketC {
  provides interface AMPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  uses interface ActiveMessageAddress;
  uses interface CXLinkPacket;
} implementation {
 
  cx_am_header_t* header(message_t* msg){
    return (cx_am_header_t*)(call SubPacket.getPayload(msg, sizeof(cx_am_header_t)));
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
    memset(header(msg), 0, sizeof(cx_am_header_t));
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_am_header_t);
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_am_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    void* ret = call SubPacket.getPayload(msg, 
      len + sizeof(cx_am_header_t));
    if (ret != NULL){
      ret += sizeof(cx_am_header_t);
    }
    return ret;
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    call SubPacket.setPayloadLength(msg, len + sizeof(cx_am_header_t));
  }

  command am_group_t AMPacket.group(message_t* amsg){
    return CX_GROUP;
  }

  command am_addr_t AMPacket.address(){
    return call ActiveMessageAddress.amAddress();
  }

  command am_addr_t AMPacket.destination(message_t* amsg){
    return (call CXLinkPacket.getLinkHeader(amsg))->destination;
  }

  command am_addr_t AMPacket.source(message_t* amsg){
    return (call CXLinkPacket.getLinkHeader(amsg))->source;
  }

  command void AMPacket.setDestination(message_t* amsg, am_addr_t addr){
    (call CXLinkPacket.getLinkHeader(amsg))->destination = addr;
  }

  command void AMPacket.setSource(message_t* amsg, am_addr_t addr){
    (call CXLinkPacket.getLinkHeader(amsg))->source = addr;
  }

  command bool AMPacket.isForMe(message_t* amsg){
    am_addr_t d = (call
    CXLinkPacket.getLinkHeader(amsg))->destination;
    return (d == call ActiveMessageAddress.amAddress()) || (d == AM_BROADCAST_ADDR);
  }

  command am_id_t AMPacket.type(message_t* amsg){
    return header(amsg)->am_type;   
  }
  command void AMPacket.setType(message_t* amsg, am_id_t t){
    header(amsg)->am_type = t;
  }
  command void AMPacket.setGroup(message_t* amsg, am_group_t grp){}
  command am_group_t AMPacket.localGroup(){return CX_GROUP;}

  async event void ActiveMessageAddress.changed(){}
}
