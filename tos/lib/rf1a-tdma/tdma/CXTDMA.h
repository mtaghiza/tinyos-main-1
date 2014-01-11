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

#ifndef CXTDMA_H
#define CXTDMA_H


#ifndef TA_DIV
#define TA_DIV 1UL
#endif

#if TA_DIV == 1UL
#define TA_SCALE 6UL
#elif TA_DIV == 2UL
#define TA_SCALE 3UL
#elif TA_DIV == 3UL
#define TA_SCALE 2UL
#elif TA_DIV == 6UL
#define TA_SCALE 1UL
#else 
#error Only 1 (6.5 MHz) 2, 3, and 6 (1.083 MHz) TA_DIV supported!
#endif

//Should be able to get this down to ~90 uS. 
// 100 uS = 108.3 ticks at 26mhz/24
#ifndef PFS_SLACK_BASE
//this was too short at full speed.
//#define PFS_SLACK_BASE (110UL * (TA_SCALE))
//#define PFS_SLACK_BASE (200UL * (TA_SCALE))
#define PFS_SLACK_BASE (600UL * (TA_SCALE))
#endif

//10 ms at 26mhz/24
#ifndef DEFAULT_TDMA_FRAME_LEN_BASE
#define DEFAULT_TDMA_FRAME_LEN_BASE (10833UL * TA_SCALE)
#endif

#ifndef DEFAULT_TDMA_FW_CHECK_LEN_BASE
//1.2 ms
#define DEFAULT_TDMA_FW_CHECK_LEN_BASE (1300UL * TA_SCALE)
//0.6 ms at 26mhz/24
//#define DEFAULT_TDMA_FW_CHECK_LEN_BASE (650UL *TA_SCALE)
#endif

#ifndef DEFAULT_TDMA_ACTIVE_FRAMES
#define DEFAULT_TDMA_ACTIVE_FRAMES 256
#endif

#ifndef DEFAULT_TDMA_INACTIVE_FRAMES
#define DEFAULT_TDMA_INACTIVE_FRAMES 0
#endif


//TODO: this should be computed based on data rate. Could also maybe
//  pick it up automatically by using carrier sense.
//125000 bps -> 8uS per bit -> 64 uS per byte -> 512 uS for preamble +
//  synch = 512 uS = 555 ticks at 26mhz/24
//  There's some extra time in here from the steps leading up to the
//  actual transmission (getting it from the upper layer, for
//  example). Which should actually be done the other way around, come
//  to think of it. So, we have to do this experimentally at the
//  moment. 
#ifndef SFD_TIME
#if TA_DIV == 1
#define SFD_TIME 3505UL
#define SFD_PROCESSING_DELAY 24
#elif TA_DIV ==6
#define SFD_TIME 583UL
//TODO: this is approximate
#define SFD_PROCESSING_DELAY 4
#else
  #error SFD_TIME not defined for this TA_DIV setting. Find by experiment.
#endif
#endif


#ifdef DEBUG_SCALE
#warning Scaling times for debug
#define TIMING_SCALE DEBUG_SCALE
#else
#define TIMING_SCALE 1
#endif


#define DEFAULT_TDMA_FRAME_LEN (DEFAULT_TDMA_FRAME_LEN_BASE * TIMING_SCALE)
//#define DEFAULT_TDMA_FW_CHECK_LEN (DEFAULT_TDMA_FW_CHECK_LEN_BASE * TIMING_SCALE)
//#define PFS_SLACK (PFS_SLACK_BASE * TIMING_SCALE)
//TODO: these should be scaled with symbol rate.
#define DEFAULT_TDMA_FW_CHECK_LEN 7000UL
#define PFS_SLACK 3500UL

#ifndef FWD_DROP_RATE
#define FWD_DROP_RATE 0
#endif

#ifndef RSSI_THRESHOLD
#define RSSI_THRESHOLD -100
#endif

#endif
