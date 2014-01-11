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


 #include "CXNetwork.h"
module CXNetworkPacketP{
  provides interface CXNetworkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  uses interface CXLinkPacket;
} implementation {

  uint16_t cxSn = 0;
  
  cx_metadata_t* metadata(message_t* msg){
    //am I losing my mind? why is it so ugly to get a pointer to this
    //struct?
    return &((message_metadata_t*)(msg -> metadata))->cx;
  }

  //CX header stuffs
  cx_network_header_t* getHeader(message_t* msg){
    return (cx_network_header_t*)(call SubPacket.getPayload(msg,
      sizeof(cx_network_header_t)));
  }


  command uint8_t CXNetworkPacket.getRXHopCount(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx->rxHopCount;
  }

  command void CXNetworkPacket.setRXHopCount(message_t* msg, 
      uint8_t rxHopCount){
    cx_metadata_t* cx = metadata(msg);
    cx -> rxHopCount = rxHopCount;
  }

  command uint32_t CXNetworkPacket.getOriginFrameNumber(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx -> originFrameNumber;
  }

  command void CXNetworkPacket.setOriginFrameNumber(message_t* msg,
      uint32_t originFrameNumber){
    cx_metadata_t* cx = metadata(msg);
    cx -> originFrameNumber = originFrameNumber;
  }

  command uint32_t CXNetworkPacket.getOriginFrameStart(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx -> originFrameStart;
  }

  command void CXNetworkPacket.setOriginFrameStart(message_t* msg,
      uint32_t originFrameStart){
    cx_metadata_t* cx = metadata(msg);
    cx -> originFrameStart = originFrameStart;
  }



  command error_t CXNetworkPacket.init(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    hdr -> hops = 0;
    call CXLinkPacket.init(msg);
    hdr->sn = cxSn++;
    return SUCCESS;
  }

  command void CXNetworkPacket.setTTL(message_t* msg, uint8_t ttl){
    cx_network_header_t* hdr = getHeader(msg);
    hdr -> ttl = ttl;
  }

  command uint8_t CXNetworkPacket.getTTL(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    return hdr->ttl;
  }

  command uint8_t CXNetworkPacket.getHops(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    return hdr->hops;
  }
  
  //if TTL positive, decrement TTL and increment hop count.
  //Return true if TTL is still positive after this step.
  command bool CXNetworkPacket.readyNextHop(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    if (hdr -> ttl > 0){
      hdr -> ttl --;
      hdr -> hops ++;
      return (hdr->ttl > 0);
    } else {
      return FALSE;
    }
  }
  //----------packet stuffs 
  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_network_header_t));
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_network_header_t);
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_network_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return (call SubPacket.getPayload(msg, sizeof(cx_network_header_t))) + sizeof(cx_network_header_t);
    } else {
      return NULL;
    }
  }

  command uint16_t CXNetworkPacket.getSn(message_t* msg){
    return getHeader(msg)->sn;   
  }
  
}
