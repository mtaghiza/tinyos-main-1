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

#ifndef CX_H
#define CX_H

#include "AM.h"
typedef nx_uint8_t cx_routing_method_t;

//size: 19 (18 if am_id is 1 byte)
typedef nx_struct cx_header_t {
  nx_uint32_t timestamp;
  nx_am_addr_t destination;
  //would like to reuse the dsn in the 15.4 header, but it's not exposed in a clean way
  nx_uint16_t sn;
  nx_uint8_t count;
  nx_uint8_t scheduleNum;
  nx_uint16_t originalFrameNum;
  nx_uint8_t nProto;
  nx_uint8_t tProto;
  nx_uint8_t type;
  nx_uint8_t ttl;
} cx_header_t;

enum{
  CX_NP_FLOOD = 0x01,
  CX_NP_SCOPEDFLOOD = 0x02,
  CX_NP_PREROUTED = 0x10,
  CX_NP_NONE = 0x00,
};

typedef nx_struct cx_ack_t{
  //DATA source id/sn
  nx_am_addr_t src;
  nx_uint16_t sn;
  //how far away the dest is from the source.
  nx_uint8_t depth;
} cx_ack_t;

typedef struct cx_metadata_t{
  uint8_t receivedCount;
  uint32_t phyTimestamp;
  uint32_t alarmTimestamp;
  uint32_t originalFrameStartEstimate;
  uint16_t frameNum;
  uint8_t symbolRate;
  bool requiresClear;
  bool ackRequested;
  bool wasAcked;
} cx_metadata_t;

#define CX_TYPE_DATA 0x01
#define CX_TYPE_ACK  0x02
#define CX_TYPE_SETUP 0x03
#define CXTDMA_RM_RESOURCE "CXTDMA.RM.Resource"

#ifndef CX_MESSAGE_POOL_SIZE
#define CX_MESSAGE_POOL_SIZE 4
#endif

#endif
