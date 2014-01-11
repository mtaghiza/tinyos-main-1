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

#include "CXLink.h"
interface CXLinkPacket {
  command void setLen(message_t* msg, uint8_t len);
  command uint8_t len(message_t* msg);
  command cx_link_header_t* getLinkHeader(message_t* msg);
  command cx_link_metadata_t* getLinkMetadata(message_t* msg);
  command rf1a_metadata_t* getPhyMetadata(message_t* msg);

  command void setAllowRetx(message_t* msg, bool allow);
//  command void setTSLoc(message_t* msg, nx_uint32_t* tsLoc);

  command void setTtl(message_t* msg, uint8_t ttl);
  command am_addr_t source(message_t* msg);
  command void setSource(message_t* msg, am_addr_t addr);
  command am_addr_t destination(message_t* msg);
  command void setDestination(message_t* msg, am_addr_t addr);
  command uint8_t rxHopCount(message_t* msg);

  command uint16_t getSn(message_t* msg);
}
