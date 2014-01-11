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

#ifndef CX_LINK_H
#define CX_LINK_H

#include "requestQueue.h"

#ifndef REQUEST_QUEUE_LEN 
//cycle sleep/wake, forward sleep/wake, net tx, trans tx, rx
#define REQUEST_QUEUE_LEN 10
#endif


#ifndef CX_SCALE_TIME
#define CX_SCALE_TIME 1
#endif

#ifndef FRAMELEN_32K
//32k = 2**15
#define FRAMELEN_32K (1024UL * CX_SCALE_TIME)
#endif

#ifndef FRAMELEN_6_5M
//6.5M = 2**5 * 5**16 * 13
#define FRAMELEN_6_5M (203125UL * CX_SCALE_TIME)
#endif

//divide both by 2**5, this is what you get.
//1024 32k ticks = 0.03125 s
//n.b. it seems like mspgcc is smart enough to see /1024 and translate
//it to >> 10. so, it's fine to divide by this defined constant.

//TIMING PARAMETERS
//These are all in 6.5MHz ticks.

//require 30uS from the time where we are 100% ready to go to the
//  scheduled transmission time.
#define MIN_STROBE_CLEARANCE 195UL

//Datasheet: IDLE->RX/FSTXON/TX 88.4 uS 
#define T_IDLE_RXTX 575UL
//difference between transmitter SFD and receiver SFD: 60.45 fast ticks
#define T_SFD_PROP_TIME 61UL
//time from strobe command to SFD: 0.00523 S
#define T_STROBE_SFD 3395UL

#ifndef SETUP_SLACK_RATIO
//scale up the nominal minimum prep time
#define SETUP_SLACK_RATIO 8UL
#endif

//Working backwards:
// receiver
//   t_sfd - T_SFD_PROP_TIME - T_STROBE_SFD = t_strobe'
// transmitter
//   t_sfd - T_STROBE_SFD = t_strobe'
//
#define TX_STROBE_CORRECTION (T_STROBE_SFD)
#define RX_STROBE_CORRECTION (T_SFD_PROP_TIME + TX_STROBE_CORRECTION)

// be ready by: t_strobe'-MIN_STROBE_CLEARANCE
// start prep at: t_strobe' - SETUP_SLACK_RATIO*T_IDLE_RXTX
// Receiver FrameTimer:
//  t_sfd - T_SFD_PROP_TIME - T_STROBE_SFD - SETUP_SLACK_RATIO*T_IDLE_RXTX
#define PREP_TIME_FAST (SETUP_SLACK_RATIO*T_IDLE_RXTX)
#define PREP_TIME_32KHZ ((FRAMELEN_32K * PREP_TIME_FAST)/FRAMELEN_6_5M)


//7800 = 1.2 ms
#ifndef RX_DEFAULT_WAIT
#define RX_DEFAULT_WAIT 7800UL
#endif 

#ifndef SNRX_SCOOT
#define SNRX_SCOOT (RX_DEFAULT_WAIT / 4)
#endif

#ifndef EARLY_WAKEUP
#define EARLY_WAKEUP (RX_DEFAULT_WAIT / 2)
#endif

#ifndef RX_MAX_WAIT
#define RX_MAX_WAIT (0x7FFFFFFF)
#endif

//if we had carrier sense when the rx timeout fires, extend by this
//amount.
//In the worst case, it will be the preamble + sfd
//For a 4-byte preamble and 4-byte synch word sequence, this is 64
//bits at 125K = 0.512 ms = 3328 6.5M ticks
#ifndef RX_EXTEND
#define RX_EXTEND 3328UL 
#endif

#ifndef ENABLE_CRC_CHECK
#define ENABLE_CRC_CHECK 1
#endif

#ifndef ENABLE_XT2_DC
#define ENABLE_XT2_DC 1
#endif

#ifndef ENABLE_TIMESTAMPING
#define ENABLE_TIMESTAMPING 1
#endif


#endif
