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

 #include "CXTDMADispatchDebug.h"

module CXTDMADispatchP{
  provides interface CXTDMA[uint8_t clientId];

  uses interface CXTDMA as SubCXTDMA;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  provides interface TaskResource[uint8_t np];
} implementation {

  enum {
    INVALID_OWNER = 0xFF,
  };

  uint16_t lastFrame;
  uint8_t owner = INVALID_OWNER;
  uint8_t lastOwner;

  
  #define PACKET_HISTORY 8
  am_addr_t recentSrc[PACKET_HISTORY] = {0xffff, 0xffff, 0xffff, 0xffff, 
    0xffff, 0xffff, 0xffff, 0xffff};
  uint16_t recentSn[PACKET_HISTORY];
  uint8_t lastIndex = 0;

  //tracking duplicates
  bool seenRecently(am_addr_t src, uint16_t sn){
    uint8_t i;
    printf_DUP("SR %u %u ", src, sn);
    for (i = 0; i < PACKET_HISTORY; i++){
      if ((src == recentSrc[i]) && (sn == recentSn[i])){
        printf_DUP("@%u\r\n", i);
        return TRUE;
      }
    }
    printf_DUP("F\r\n");
    return FALSE;
  }

  void recordReception(am_addr_t src, uint16_t sn){
    printf_DUP("RR %u %u @%u\r\n", src, sn, lastIndex);
    recentSrc[lastIndex] = src;
    recentSn[lastIndex] = sn;
    lastIndex = ((lastIndex+1) % PACKET_HISTORY);
  }


  command error_t TaskResource.immediateRequest[uint8_t np](){
    if (owner == INVALID_OWNER){
      owner = np;
      return SUCCESS;
    }else{
      return FAIL;
    }
  }

  command error_t TaskResource.release[uint8_t np](){
    if (owner == np){
      lastOwner = owner;
      owner = INVALID_OWNER;
      return SUCCESS;
    }
    return FAIL;
  }

  command bool TaskResource.isOwner[uint8_t np](){
    return np == owner;
  }

  bool isClaimed(){
    return owner != INVALID_OWNER;
  }

  event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    lastFrame = frameNum;
    if ( isClaimed() ){
      return signal CXTDMA.frameType[owner](frameNum);
    } else {
      rf1a_offmode_t ret;
      ret = signal CXTDMA.frameType[CX_NP_FLOOD](frameNum);
      if ( ! isClaimed()){
        ret = signal CXTDMA.frameType[CX_NP_SCOPEDFLOOD](frameNum);
      }
      if ( ! isClaimed()){
        ret = RF1A_OM_RX;
      }
      return ret;
    }
  }

  event bool SubCXTDMA.getPacket(message_t** msg,
      uint16_t frameNum){ 
    if ( isClaimed() ){
      bool r = signal CXTDMA.getPacket[owner](msg,
        frameNum);
      if (msg != NULL){
        recordReception(call CXPacket.source(*msg), 
          call CXPacket.sn(*msg));
      }
      return r;
    } else {
      return FALSE;
    }
  }

  event error_t SubCXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (isClaimed()){
      return signal CXTDMA.sendDone[owner](msg, len, frameNum, error);
    } else {
      printf("!Unclaimed SD@ %u (last: %x)\r\n", frameNum, lastOwner);
      return FAIL;
    }
  }

  message_t* dispMsg;
  task void displayPacket(){
    printf(" CX d: %x sn: %x count: %x sched: %x of: %x ts: %lx np: %x tp: %x ntype: %x ptype: %x\r\n", 
      call CXPacket.destination(dispMsg),
      call CXPacket.sn(dispMsg),
      call CXPacket.count(dispMsg),
      call CXPacket.getScheduleNum(dispMsg),
      call CXPacket.getOriginalFrameNum(dispMsg),
      call CXPacket.getTimestamp(dispMsg),
      call CXPacket.getNetworkProtocol(dispMsg),
      call CXPacket.getTransportProtocol(dispMsg),
      call CXPacket.getNetworkType(dispMsg),
      call CXPacket.getTransportType(dispMsg));
   }

  event message_t* SubCXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
//    printf_TMP("#D %x\r\n",
//      call CXPacket.getNetworkProtocol(msg) & ~CX_NP_PREROUTED);

    //check for duplicates 
    if (!seenRecently(call CXPacket.source(msg), call CXPacket.sn(msg))){
      recordReception(call CXPacket.source(msg), call CXPacket.sn(msg));
      return signal CXTDMA.receive[ call CXPacket.getNetworkProtocol(msg) & ~CX_NP_PREROUTED](msg, len, frameNum, timestamp);
    }else{
      return msg;
    }
  }

  default event rf1a_offmode_t CXTDMA.frameType[uint8_t NetworkProtocol](uint16_t frameNum){
    return RF1A_OM_RX;
  }
  default event bool CXTDMA.getPacket[uint8_t NetworkProtocol](message_t** msg, 
      uint16_t frameNum){ return FALSE;}
  default event error_t CXTDMA.sendDone[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){ return SUCCESS;}

  default event message_t* CXTDMA.receive[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    printf("!Unhandled np %x @%u\r\n", NetworkProtocol, frameNum);
    return msg;
  }

}
