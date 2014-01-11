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

#ifndef CX_MAC_H
#define CX_MAC_H

#include "CXLink.h"
#include "multiNetwork.h"
#include "GlobalID.h"

#define CXM_DATA 0
#define CXM_PROBE 1
#define CXM_KEEPALIVE 2
#define CXM_CTS 3
#define CXM_RTS 4
#define CXM_STATUS 5
#define CXM_EOS 6

#define SS_KEY_PROBE_SCHEDULE 0x15

//N.B. nesC doesn't handle initialization of multi-byte nx_* fields in
//structs correctly. Arrays of single-byte elements can safely be left
//"native". In the initialization of these guys, probeInterval will be
//left uninitialized (and set during software init)
typedef struct probe_schedule {
   nx_uint32_t probeInterval;
   uint8_t channel[NUM_SEGMENTS];
   uint8_t invFrequency[NUM_SEGMENTS];
   uint8_t bw[NUM_SEGMENTS];
   uint8_t maxDepth[NUM_SEGMENTS];
   nx_uint32_t wakeupLen[NUM_SEGMENTS];
} probe_schedule_t;

typedef nx_struct cx_mac_header{
  nx_uint8_t macType;
} cx_mac_header_t;

typedef nx_struct cx_lpp_probe {
  nx_uint16_t rc;
  nx_uint32_t tMilli;
} cx_lpp_probe_t;

#ifndef LPP_DEFAULT_PROBE_INTERVAL
#define LPP_DEFAULT_PROBE_INTERVAL 5120UL
#endif

#ifndef LPP_SLEEP_TIMEOUT
#define LPP_SLEEP_TIMEOUT 30720UL
#endif

#define CX_KEEPALIVE_RETRY 512UL

//On the logic analyzer, there is a 1.02 ms gap between the end of the
//probe TX and the SFD from its rebroadcast. In practice, we're not
//going to be able to start listening for the ack immediately, so
//using a 1.02 ms timeout is pretty conservative.
#define CHECK_TIMEOUT (6630UL + (FRAMELEN_FAST_SHORT - 24700UL))

//This constant is put in to accommodate RX extensions due to channel
//activity detection at the link layer.
#ifndef CHECK_TIMEOUT_PADDING
#define CHECK_TIMEOUT_PADDING 18
#endif

#define CHECK_TIMEOUT_SLOW (34UL + CHECK_TIMEOUT_PADDING)

//roughly 660 seconds
#define RX_TIMEOUT_MAX (0xFFFFFFFF)
//Add 50% for safety
#define RX_TIMEOUT_MAX_SLOW 1014934UL

#define MAC_RETRY_LIMIT 4

#ifndef CX_BASESTATION 
#define CX_BASESTATION 0
#endif

#ifndef CX_NEIGHBORHOOD_SIZE
#define CX_NEIGHBORHOOD_SIZE 16
#endif

//Basestation control messages
typedef nx_struct cx_lpp_wakeup {
  nx_uint32_t timeout;
} cx_lpp_wakeup_t;

typedef nx_struct cx_lpp_sleep {
  nx_uint32_t delay;
} cx_lpp_sleep_t;

typedef nx_struct cx_lpp_cts {
  nx_int16_t slotNum;
} cx_lpp_cts_t;

typedef nx_struct cx_status {
  nx_uint8_t distance;
  nx_uint8_t dataPending;
  nx_uint8_t bw;
  nx_uint16_t wakeupRC;
  nx_uint32_t wakeupTS;
  nx_uint32_t pushCookie;
  nx_uint32_t writeCookie;
  nx_uint32_t missingLength;
  nx_uint8_t subnetChannel;
  nx_uint32_t sampleInterval;
  nx_uint8_t role;
  nx_uint8_t barcode[GLOBAL_ID_LEN];
  nx_am_addr_t neighbors[CX_NEIGHBORHOOD_SIZE];
} cx_status_t; 

typedef nx_struct cx_eos {
  nx_uint8_t dataPending;
} cx_eos_t;

enum {
 AM_CX_LPP_WAKEUP=0xC6,
 AM_CX_LPP_SLEEP=0xC7,
 AM_CX_LPP_CTS=0xC8,
 AM_CX_STATUS=0xD3,
};

#endif
