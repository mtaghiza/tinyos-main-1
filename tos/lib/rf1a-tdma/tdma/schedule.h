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

#ifndef SCHEDULE_H
#define SCHEDULE_H

#include "message.h"
#include "CXTDMA.h"
#include "TimingConstants.h"

#define CX_TYPE_SCHEDULE 0xac
#define CX_TYPE_SCHEDULE_REPLY 0xad

typedef nx_struct cx_schedule_t {
  nx_uint8_t scheduleNum;
  nx_uint8_t symbolRate;
  nx_uint8_t scheduleId;
//  nx_uint8_t padding[TOSH_DATA_LENGTH - sizeof(cx_header_t) -
//    sizeof(message_header_t) - 3*sizeof(nx_uint8_t) ];
} cx_schedule_t;

typedef struct cx_schedule_descriptor_t {
//  nx_uint32_t frameLen;
//  nx_uint32_t fwCheckLen;
  uint16_t activeFrames;
  uint16_t inactiveFrames;
  uint16_t framesPerSlot;
  uint8_t  maxRetransmit;
  uint8_t channel;
} cx_schedule_descriptor_t;

typedef nx_struct cx_schedule_reply_t{
  nx_uint8_t scheduleNum;
} cx_schedule_reply_t;

#ifndef TDMA_ROOT
#define TDMA_ROOT 0
#endif

//in units of frames, maybe that's dumb
#ifndef SCHEDULE_TIMEOUT
#define SCHEDULE_TIMEOUT 1024
#endif

#ifndef CX_ADAPTIVE_SR
#define CX_ADAPTIVE_SR 1
#endif

#if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
#ifndef TDMA_ROOT_FRAMES_PER_SLOT
#define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
#endif
#define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
#define TDMA_ROOT_INACTIVE_FRAMES 5
#else
#error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
#endif

#define TDMA_INIT_SCHEDULE_ID 0

const cx_schedule_descriptor_t SCHEDULES[1] = {
  { TDMA_ROOT_ACTIVE_FRAMES, TDMA_ROOT_INACTIVE_FRAMES,
  TDMA_ROOT_FRAMES_PER_SLOT, TDMA_MAX_RETRANSMIT, TEST_CHANNEL},
};



#endif
