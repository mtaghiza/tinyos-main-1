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
//TODO: switch to cx_addr, cx_id 
interface CXPacket{
//  command am_addr_t address();
  command void init(message_t* amsg);
  command am_addr_t destination(message_t* amsg);
  command am_addr_t source(message_t* amsg);
  command void setDestination(message_t* amsg, am_addr_t addr);
  command void setSource(message_t* amsg, am_addr_t addr);
  command uint16_t sn(message_t* amsg);
  command void newSn(message_t* amsg);
  command uint8_t count(message_t* amsg);
  command void setCount(message_t* amsg, uint8_t cxcount);
  command void incCount(message_t* amsg);
  command bool isForMe(message_t* amsg);
  //Type = ACK or DATA (used at network layer)
  command uint8_t getNetworkType(message_t* amsg);
  command void setNetworkType(message_t* amsg, am_id_t t);
  //Type = SETUP or DATA (used at transport layer)
  command uint8_t getTransportType(message_t* amsg);
  command void setTransportType(message_t* amsg, am_id_t t);
  command void setNetworkProtocol(message_t* amsg, uint8_t t);
  command uint8_t getNetworkProtocol(message_t* amsg);
  command void setTransportProtocol(message_t* amsg, uint8_t t);
  command uint8_t getTransportProtocol(message_t* amsg);
  command void setTimestamp(message_t* amsg, uint32_t ts);
  command uint32_t getTimestamp(message_t* amsg);
  command void setScheduleNum(message_t* amsg, uint8_t scheduleNum);
  command uint8_t getScheduleNum(message_t* amsg);
  command void setOriginalFrameNum(message_t* amsg, uint16_t frameNum);
  command uint16_t getOriginalFrameNum(message_t* amsg);
  command bool ackRequested(message_t* msg);
  command uint8_t getTTL(message_t* amsg);
  command void setTTL(message_t* amsg, uint8_t ttl);
  command void decTTL(message_t* amsg);
  //used for doing precision timestamping: this lets the user know
  //where to pause in the transmission.
  command const uint8_t* getTimestampAddr(message_t* amsg);
}
