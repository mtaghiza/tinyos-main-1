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

#ifndef CX_SCHEDULE_H
#define CX_SCHEDULE_H

#include "CXLink.h"

#define FRAME_LENGTH FRAMELEN_SLOW

#ifndef FRAMES_PER_SLOT
#define FRAMES_PER_SLOT 30
#endif

#define SLOT_LENGTH FRAME_LENGTH * FRAMES_PER_SLOT

//This is the time, in 32k ticks, by which receivers attempt to
//  precede the sender. If they are perfectly synchronized, then the
//  IDLE ->RX time and the IDLE->TX time are equal (88 uS). 3 ticks is
//  91 uS, so we can miss by a lot and still hit it.
#ifndef RX_SLACK
#define RX_SLACK 10UL
#endif

//This is the time, in 32k ticks, which the sender uses to load its
//packet for transmission.
// Timer fires at frameboundary - TX_SLACK + d0
// Packet txTime is set to frame-boundary
// Send is called at frameboundary - TX_SLACK + d0 + d1
// At frame boundary, TX strobe is sent.
#ifndef TX_SLACK
#define TX_SLACK 30UL
#endif


//Could be off by one 32K tick
#define ASYNCHRONY_32K 198UL
//looks like around 100 uS between the tx strobe and the carrier sense
//  detection at the forwarder.
#define CS_PROPAGATION 650UL

//delay between the sched-layer frame timer.fired event and the link
//layer fastalarm.fired event. 
//TODO: This should be nowhere near this high, even if you take into
//account encoding time + transition from idle to FSTXON.
#define SCHED_TX_DELAY 6000UL

//Put it all together and convert to fast ticks
// - the slack itself
// - clock asynchrony
// - carrier sense prop time
// - delay between sender frame timer/actual tx start
#define DATA_TIMEOUT (ASYNCHRONY_32K + CS_PROPAGATION + SCHED_TX_DELAY + ((RX_SLACK * 2UL* FRAMELEN_FAST_NORMAL) / FRAMELEN_SLOW))

#define CTS_TIMEOUT (ASYNCHRONY_32K + CS_PROPAGATION + FRAMELEN_FAST_SHORT*CX_MAX_DEPTH + ((RX_SLACK * 2UL* FRAMELEN_FAST_NORMAL) / FRAMELEN_SLOW))

//EOS_FRAMES: integer for the number of partial full-length frames required by a
//max-depth fast flood. e.g. if FLFS is 1/5 of a normal frame and
//max_depth is 11, we need to allow 2.2 frames (roundd up to 3) for the EOS message in
//order for it to not interfere with the start of the next slot.
#define EOS_FRAMES ((CTS_TIMEOUT / FRAMELEN_FAST_NORMAL) + 1)

#ifndef CX_DEFAULT_BW
#define CX_DEFAULT_BW 2
#endif

//This is in 32K ticks, not ms
#define CX_WAKEUP_LEN ((LPP_DEFAULT_PROBE_INTERVAL * CX_MAX_DEPTH) << 5)

//back to sleep when we miss this many CTS packets in a download.
#ifndef MISSED_CTS_THRESH
#define MISSED_CTS_THRESH 4
#endif

#ifndef ENABLE_FORWARDER_SELECTION
#define ENABLE_FORWARDER_SELECTION 1
#endif

#endif
