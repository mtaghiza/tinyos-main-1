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


 #include "CXLinkDebug.h"
module CXLinkPacketP {
  provides interface CXLinkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  
  uses interface Ieee154Packet;
  uses interface Rf1aPacket;
  uses interface CXPacketMetadata;

} implementation {
  command am_addr_t CXLinkPacket.getSource(message_t* msg){
    return call Ieee154Packet.source(msg);  
  }

  command void CXLinkPacket.setSource(message_t* msg, am_addr_t addr){
    call Ieee154Packet.setSource(msg, addr);
  }

  command am_addr_t CXLinkPacket.addr(){
    return call Ieee154Packet.address();
  }

  command void CXLinkPacket.init(message_t* msg){
    call Rf1aPacket.configureAsData(msg);
    call CXLinkPacket.setSource(msg, call CXLinkPacket.addr());
  }

  command void Packet.clear(message_t* msg){
    cdbg(LINKQUEUE, "clr p %p\r\n", msg);
    call SubPacket.clear(msg);
    call CXPacketMetadata.setRequestedFrame(msg, INVALID_FRAME);
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg);
  }
  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    call SubPacket.setPayloadLength(msg, len);
  }
  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength();
  }
  command void* Packet.getPayload(message_t* msg, uint8_t len){
    return call SubPacket.getPayload(msg, len);
  }


}
