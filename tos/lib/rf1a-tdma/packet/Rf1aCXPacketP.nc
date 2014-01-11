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
 #include "CXPacketDebug.h"
 #include "CXPacket.h"

module Rf1aCXPacketP{
  provides interface CXPacket;
  provides interface Packet;
  provides interface CXPacketMetadata;
  provides interface PacketAcknowledgements;
  uses interface AMPacket as AMPacket;
  uses interface Packet as SubPacket;
  uses interface Rf1aPacket; 
  uses interface Ieee154Packet;
  uses interface ActiveMessageAddress;
} implementation {
  //this should probably be longer, right?
  uint16_t cxSN = 0;
  
  cx_header_t* getHeader(message_t* msg){
    return (cx_header_t*)(call SubPacket.getPayload(msg, sizeof(cx_header_t)));
  }

  cx_metadata_t* getMetadata(message_t* msg){
    return &(((message_metadata_t*)(msg->metadata))->cx);
  }

  command const uint8_t* CXPacket.getTimestampAddr(message_t* amsg){
    return (const uint8_t*)(&(getHeader(amsg)->timestamp));
  }

  command void CXPacket.init(message_t* msg){
    call Rf1aPacket.configureAsData(msg);
    call AMPacket.setSource(msg, call AMPacket.address());
    call Ieee154Packet.setPan(msg, call Ieee154Packet.localPan());
    call CXPacket.setCount(msg, 0);
    call CXPacket.newSn(msg);
  }

  async command error_t PacketAcknowledgements.requestAck(message_t* msg){
    getMetadata(msg)->ackRequested = 1;
    return SUCCESS;
  }
  async command error_t PacketAcknowledgements.noAck(message_t* msg){
    getMetadata(msg)->ackRequested = 0;
    return SUCCESS;
  }
  async command bool PacketAcknowledgements.wasAcked(message_t* msg){
    return getMetadata(msg)->wasAcked;
  }
  command bool CXPacket.ackRequested(message_t* msg){
    return getMetadata(msg)->ackRequested;
  }

  command void Packet.clear(message_t* msg) {
    call SubPacket.clear(msg);
    //TODO: reset anything germane to this header
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
//    printf_TMP("CX.spl %u + %u\r\n", len, sizeof(cx_header_t));
    call SubPacket.setPayloadLength(msg, len + sizeof(cx_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    uint8_t ret = call SubPacket.maxPayloadLength() - sizeof(cx_header_t);
    printf_PACKET("p.mpl %u - %u = %u\r\n", 
      call SubPacket.maxPayloadLength(), sizeof(cx_header_t), ret);
    return ret;
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    void* ret;
    printf_PACKET("cx.gp %u \r\n", len);
    if (len <= call Packet.maxPayloadLength()){
      ret = (void*) (sizeof(cx_header_t) + (call SubPacket.getPayload(msg,
        len+sizeof(cx_header_t))));
    } else {
      ret = 0;
    }
    printf_PACKET("/cx.gp %p (%p) %u: %p\r\n", msg, 
      call SubPacket.getPayload(msg, len + sizeof(cx_header_t)), 
      len, ret);
    return ret;
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
  command uint16_t CXPacket.sn(message_t* amsg){
    return getHeader(amsg)->sn;
  }

  command void CXPacket.newSn(message_t* amsg){
    getHeader(amsg)->sn = cxSN ++;
  }

  command uint8_t CXPacket.count(message_t* amsg){
    return getHeader(amsg)->count;
  }

  command void CXPacket.setCount(message_t* amsg, uint8_t cxcount){
    getHeader(amsg)->count = cxcount;
  }
  command void CXPacket.incCount(message_t* amsg){
    getHeader(amsg)->count++;
  }


  command bool CXPacket.isForMe(message_t* amsg){
    return (call CXPacket.destination(amsg) == call
    ActiveMessageAddress.amAddress() ||
            call CXPacket.destination(amsg) == AM_BROADCAST_ADDR);
  }

  command uint8_t CXPacket.getNetworkProtocol(message_t* amsg){
    return getHeader(amsg)->nProto;
  }
  command void CXPacket.setNetworkProtocol(message_t* amsg,
      uint8_t t){
    getHeader(amsg)->nProto = t;
  }

  command uint8_t CXPacket.getNetworkType(message_t* amsg){
    return (getHeader(amsg)->type) & CX_NETWORK_TYPE_MASK;
  }
  command void CXPacket.setNetworkType(message_t* amsg,
      uint8_t t){
    getHeader(amsg)->type &= ~CX_NETWORK_TYPE_MASK;
    getHeader(amsg)->type |= (t & CX_NETWORK_TYPE_MASK);
  }

  command uint8_t CXPacket.getTransportType(message_t* amsg){
    return ((getHeader(amsg)->type) & CX_TRANSPORT_TYPE_MASK) >> 4;
  }
  command void CXPacket.setTransportType(message_t* amsg,
      uint8_t t){
    getHeader(amsg)->type &= ~CX_TRANSPORT_TYPE_MASK;
    getHeader(amsg)->type |= ((t << 4) & CX_TRANSPORT_TYPE_MASK);
  }


  command uint8_t CXPacket.getTransportProtocol(message_t* amsg){
    return getHeader(amsg)->tProto;
  }
  command void CXPacket.setTransportProtocol(message_t* amsg,
      uint8_t t){
    getHeader(amsg)->tProto = t;
  }


  command uint32_t CXPacket.getTimestamp(message_t* amsg){
    return getHeader(amsg)->timestamp;
  }
  command void CXPacket.setTimestamp(message_t* amsg,
      uint32_t ts){
    getHeader(amsg)->timestamp = ts;
  }

//  command void CXPacketMetadata.setAlarmTimestamp(message_t* amsg, uint32_t ts){
//    getMetadata(amsg)->alarmTimestamp = ts;
//  }
//  command uint32_t CXPacketMetadata.getAlarmTimestamp(message_t* amsg){
//    return getMetadata(amsg)->alarmTimestamp;
//  }
  command void CXPacketMetadata.setPhyTimestamp(message_t* amsg, uint32_t ts){
    getMetadata(amsg)->phyTimestamp = ts;
  }
  command uint32_t CXPacketMetadata.getPhyTimestamp(message_t* amsg){
    return getMetadata(amsg)->phyTimestamp;
  }
  
  command void CXPacketMetadata.setOriginalFrameStartEstimate(
      message_t* amsg, uint32_t ts){
    getMetadata(amsg)->originalFrameStartEstimate = ts;
  }

  command uint32_t CXPacketMetadata.getOriginalFrameStartEstimate(message_t* amsg){
    return getMetadata(amsg)->originalFrameStartEstimate;
  }

  command void CXPacketMetadata.setFrameNum(message_t* amsg, uint16_t frameNum){
    getMetadata(amsg)->frameNum = frameNum;
  }
  command uint16_t CXPacketMetadata.getFrameNum(message_t* amsg){
    return getMetadata(amsg)->frameNum;
  }
  command void CXPacketMetadata.setReceivedCount(message_t* amsg,
      uint8_t receivedCount){
    getMetadata(amsg)->receivedCount = receivedCount;
  }
  command uint8_t CXPacketMetadata.getReceivedCount(message_t* amsg){
    return getMetadata(amsg)->receivedCount;
  }

  command void CXPacketMetadata.setSymbolRate(message_t* amsg,
      uint8_t symbolRate){
    getMetadata(amsg)->symbolRate = symbolRate;
  }
  command uint8_t CXPacketMetadata.getSymbolRate(message_t* amsg){
    return getMetadata(amsg)->symbolRate;
  }

  command void CXPacket.setScheduleNum(message_t* amsg,
      uint8_t scheduleNum){
    getHeader(amsg)->scheduleNum = scheduleNum;
  }
  command uint8_t CXPacket.getScheduleNum(message_t* amsg){
    return getHeader(amsg)->scheduleNum;
  }

  command void CXPacket.setOriginalFrameNum(message_t* amsg,
      uint16_t originalFrameNum){
    getHeader(amsg)->originalFrameNum = originalFrameNum;
  }
  command uint16_t CXPacket.getOriginalFrameNum(message_t* amsg){
    return getHeader(amsg)->originalFrameNum;
  }

  command void CXPacketMetadata.setRequiresClear(message_t* amsg,
      bool requiresClear){
    getMetadata(amsg)->requiresClear = requiresClear;
  }
  command bool CXPacketMetadata.getRequiresClear(message_t* amsg){
    return getMetadata(amsg)->requiresClear;
  }

  command uint8_t CXPacket.getTTL(message_t* amsg){
    return getHeader(amsg)->ttl;
  }
  command void CXPacket.setTTL(message_t* amsg,
      uint8_t ttl){
    getHeader(amsg)->ttl = ttl;
  }
  command void CXPacket.decTTL(message_t* amsg){
    getHeader(amsg)->ttl--;
  }


  async event void ActiveMessageAddress.changed(){ }
}
