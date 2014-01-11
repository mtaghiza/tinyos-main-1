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


 #include "CXTransport.h"
module CXTransportPacketP{
  provides interface Packet;
  uses interface Packet as SubPacket;
  provides interface CXTransportPacket;
} implementation {
  cx_transport_header_t* getHeader(message_t* msg){
    return (cx_transport_header_t*)(call SubPacket.getPayload(msg,
      sizeof(cx_transport_header_t)));
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
    getHeader(msg) -> tproto = CX_INVALID_TP;
    getHeader(msg) -> distance = CX_INVALID_DISTANCE;
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) -
      sizeof(cx_transport_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_transport_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() -
      sizeof(cx_transport_header_t);
  }

  command void* Packet.getPayload(message_t* msg, 
      uint8_t len){
    void* pl = call SubPacket.getPayload(msg,
      len + sizeof(cx_transport_header_t));
    if (pl){
      return pl + sizeof(cx_transport_header_t);
    }else{
      return pl;
    }
  }

  command uint8_t CXTransportPacket.getDistance(message_t* msg){
    return (getHeader(msg) -> distance);
  }

  command uint8_t CXTransportPacket.getProtocol(message_t* msg){
    return (getHeader(msg) -> tproto) & CX_TP_PROTO_MASK;
  }
  command uint8_t CXTransportPacket.getSubprotocol(message_t* msg){
    return (getHeader(msg) -> tproto) & ~CX_TP_PROTO_MASK;
  }

  command void CXTransportPacket.setDistance(message_t* msg,
      uint8_t distance){
    getHeader(msg) -> distance = distance;
  }

  command void CXTransportPacket.setProtocol(message_t* msg,
      uint8_t tproto){
    cx_transport_header_t* hdr = getHeader(msg);
//    printf("%x => %x | %x", 
//      hdr->tproto,
//      (hdr->tproto & ~CX_TP_PROTO_MASK),
//      (tproto & CX_TP_PROTO_MASK));
    hdr->tproto = (hdr->tproto & ~CX_TP_PROTO_MASK) | (tproto & CX_TP_PROTO_MASK);
//    printf(" = %x\r\n",
//      hdr->tproto);
  }

  command void CXTransportPacket.setSubprotocol(message_t* msg,
      uint8_t subproto){
    cx_transport_header_t* hdr = getHeader(msg);
    hdr -> tproto = (hdr->tproto & CX_TP_PROTO_MASK) | (subproto & ~CX_TP_PROTO_MASK);
  }

}
