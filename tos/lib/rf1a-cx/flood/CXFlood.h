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

#ifndef CX_FLOOD_H
#define CX_FLOOD_H

#define CX_TYPE_FLOOD_ANNOUNCEMENT 0x00
#define CX_TYPE_FLOOD_DATA 0x01

typedef nx_struct cx_flood_announcement_t {
  nx_uint32_t period;
  nx_uint32_t frameLen;
  nx_uint16_t numFrames;
} cx_flood_announcement_t;

//TODO: these should both be derived from a single value. note that
//  XT2DIV is not a nice multiple of 2**15
#ifndef STARTSEND_SLACK_32KHZ
#define STARTSEND_SLACK_32KHZ 10
#endif
#ifndef STARTSEND_SLACK_XT2DIV
#define STARTSEND_SLACK_XT2DIV 1024
#endif

//TODO: tune this down as low as possible
#ifndef CX_FLOOD_RETX_DELAY
#define CX_FLOOD_RETX_DELAY 400
#endif

#ifndef CX_FLOOD_QUEUE_LEN
#define CX_FLOOD_QUEUE_LEN 16
#endif

#ifndef CX_FLOOD_FAILSAFE_LIMIT
#define CX_FLOOD_FAILSAFE_LIMIT 4
#endif

#ifndef CX_FLOOD_RADIO_START_SLACK
#define CX_FLOOD_RADIO_START_SLACK 10
#endif

//milliseconds
#ifndef CX_FLOOD_DEFAULT_PERIOD
#define CX_FLOOD_DEFAULT_PERIOD 5120
#endif

//32khz ticks: 256 = 8 ms
#ifndef CX_FLOOD_DEFAULT_FRAMELEN
#define CX_FLOOD_DEFAULT_FRAMELEN 256
#endif

#ifndef CX_FLOOD_DEFAULT_NUMFRAMES
#define CX_FLOOD_DEFAULT_NUMFRAMES 64
#endif

#define XT2_32KHZ_RATIO 200

//programmed delay of 15000 ticks: see alarm at app level after
//14711.125 ticks. unclear why, this behavior doesn't seem to be
//present with the 32k timer.
//#define MYSTERY_OFFSET 289
#define MYSTERY_OFFSET 0
#endif
