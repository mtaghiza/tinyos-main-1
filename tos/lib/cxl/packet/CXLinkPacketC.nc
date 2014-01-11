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

module CXLinkPacketC{
  provides interface Packet;
  provides interface CXLinkPacket;
  provides interface MessageRssi;
  provides interface MessageLqi;
  uses interface Rf1aPhysicalMetadata;
} implementation {
  
  message_metadata_t* md(const message_t* msg){
    return (message_metadata_t*)(msg->metadata);
  }

  const rf1a_metadata_t* cmetadata_ (const message_t* msg) { 
    return (const rf1a_metadata_t*)&(md(msg)->rf1a); 
  }

  command void CXLinkPacket.setTtl(message_t* msg, 
      uint8_t ttl){
    (call CXLinkPacket.getLinkHeader(msg))->ttl = ttl;
  }
  command int MessageRssi.rssi (const message_t* msg) { 
    return call Rf1aPhysicalMetadata.rssi(cmetadata_(msg)); 
  }
  command int MessageLqi.lqi (const message_t* msg) { 
    return call Rf1aPhysicalMetadata.lqi(cmetadata_(msg)); 
  }

  command void CXLinkPacket.setSource(message_t* msg, 
      am_addr_t addr){
    (call CXLinkPacket.getLinkHeader(msg))->source = addr;
  }

  command void CXLinkPacket.setDestination(message_t* msg,
      am_addr_t addr){
    (call CXLinkPacket.getLinkHeader(msg))->destination = addr;
  }
  
  command am_addr_t CXLinkPacket.source(message_t* msg){
    return (call CXLinkPacket.getLinkHeader(msg))->source;
  }

  command am_addr_t CXLinkPacket.destination(message_t* msg){
    return (call CXLinkPacket.getLinkHeader(msg))->destination;
  }

  command uint8_t CXLinkPacket.rxHopCount(message_t* msg){
    return (call CXLinkPacket.getLinkMetadata(msg))->rxHopCount;
  }

  command void CXLinkPacket.setAllowRetx(message_t* msg, bool allowRetx){
    md(msg)->cx.retx = allowRetx;
  }

//  command void CXLinkPacket.setTSLoc(message_t* msg, 
//      nx_uint32_t* tsLoc){
//    md(msg)->cx.tsLoc = tsLoc;
//  }
//  
  //These commands deal with the *real* packet length (including
  //padding)
  command void CXLinkPacket.setLen(message_t* msg, uint8_t len){
    md(msg)->rf1a.payload_length = len - sizeof(message_header_t);
  }
  command uint8_t CXLinkPacket.len(message_t* msg){
    return md(msg)->rf1a.payload_length + sizeof(message_header_t);
  }

  command cx_link_header_t* CXLinkPacket.getLinkHeader(message_t* msg){
    return (cx_link_header_t*)(msg->header);
  }

  command cx_link_metadata_t* CXLinkPacket.getLinkMetadata(message_t* msg){
    return &(md(msg)->cx);
  }

  command rf1a_metadata_t* CXLinkPacket.getPhyMetadata(message_t* msg){
    return &(md(msg)->rf1a);
  }

  command void Packet.clear(message_t* msg){
    memset(call CXLinkPacket.getLinkHeader(msg), 
      0, 
      sizeof(cx_link_header_t));
    memset(md(msg), 
      0, 
      sizeof(message_metadata_t));
    //set up defaults: allow retx from this buffer.
    md(msg)->cx.retx = TRUE;
    //kind of hacky: set the lqi of the phy metadata so that this
    //looks like passed. otherwise, self re-tx will fail.
    md(msg)->rf1a.lqi = 0x80;
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return msg->data;
    }else {
      return NULL;
    }
  }
  

  //get payload length: just read from the header.
  command uint8_t Packet.payloadLength(message_t* msg){
    return (call CXLinkPacket.getLinkHeader(msg))->bodyLen;
  }
  
  //Set payload length: fill in bodyLen in header, set payload length
  //in metadata
  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    (call CXLinkPacket.getLinkHeader(msg))->bodyLen = len;
    call CXLinkPacket.setLen(msg, len + sizeof(message_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return TOSH_DATA_LENGTH;
  }

  command uint16_t CXLinkPacket.getSn(message_t* msg){
    return ((cx_link_header_t*)(msg->header))->sn;
  }

}
