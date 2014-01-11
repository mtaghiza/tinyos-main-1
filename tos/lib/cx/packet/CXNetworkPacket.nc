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

interface CXNetworkPacket {

  //reset hop count, set source address
  command error_t init(message_t* msg);

  command void setTTL(message_t* msg, uint8_t ttl); 
  command uint8_t getTTL(message_t* msg);

  command uint8_t getHops(message_t* msg);
  
  //if TTL positive, decrement TTL and increment hop count.
  //Return true if TTL is still positive after this step.
  command bool readyNextHop(message_t* msg);

  command uint8_t getRXHopCount(message_t* msg);
  command void setRXHopCount(message_t* msg, 
      uint8_t rxHopCount);
  command uint32_t getOriginFrameNumber(message_t* msg);
  command void setOriginFrameNumber(message_t* msg,
      uint32_t originFrameNumber);
  command uint32_t getOriginFrameStart(message_t* msg);
  command void setOriginFrameStart(message_t* msg,
      uint32_t originFrameStart);
  
  command uint16_t getSn(message_t* msg);

}
