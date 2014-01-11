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

interface CXPacketMetadata{
  command void setPhyTimestamp(message_t* amsg, uint32_t ts);
  command uint32_t getPhyTimestamp(message_t* amsg);
//  command void setAlarmTimestamp(message_t* amsg, uint32_t ts);
//  command uint32_t getAlarmTimestamp(message_t* amsg);
  command void setFrameNum(message_t* amsg, uint16_t ts);
  command uint16_t getFrameNum(message_t* amsg);
  command void setReceivedCount(message_t* amsg, uint8_t rc);
  command uint8_t getReceivedCount(message_t* amsg);
  command void setSymbolRate(message_t* amsg, uint8_t symbolRate);
  command uint8_t getSymbolRate(message_t* amsg);
  command void setRequiresClear(message_t* amsg, bool rc);
  command bool getRequiresClear(message_t* amsg);
  command void setOriginalFrameStartEstimate(message_t* amsg, 
    uint32_t ts);
  command uint32_t getOriginalFrameStartEstimate(message_t* amsg);
}
