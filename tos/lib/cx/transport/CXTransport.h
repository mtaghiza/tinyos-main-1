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

#ifndef CX_TRANSPORT_H
#define CX_TRANSPORT_H

typedef nx_struct cx_transport_header {
  nx_uint8_t tproto;
  nx_uint16_t distance;
} cx_transport_header_t;

typedef nx_struct cx_ack {
  nx_uint8_t distance;
  nx_uint8_t bw;
  nx_uint16_t sn;
} cx_ack_t;

#define AM_CX_RR_ACK_MSG 0xC5

#define CX_TP_FLOOD_BURST 0x00
#define CX_TP_RR_BURST 0x01
#define CX_TP_SCHEDULED 0x02

#define CX_SP_DATA  0x00
#define CX_SP_SETUP 0x10
#define CX_SP_ACK   0x20

#define NUM_RX_TRANSPORT_PROTOCOLS 2

//upper nibble is available for distinguishing data/ack/setup, etc
#define CX_TP_PROTO_MASK 0x0F
#define CX_INVALID_TP 0xFF
#define CX_INVALID_SP 0xF0
#define CX_INVALID_DISTANCE 0xFF

//default frame len is 2^10 * 2^-15 = 2^-5 S
//set retry to 1/4 frame len: 2^-7 = 2^-10 * X
//                            2^-7 * 2^10  = 2^3 = 8
#ifndef TRANSPORT_RETRY_TIMEOUT
#define TRANSPORT_RETRY_TIMEOUT 8UL
#endif

//retry up to 4x per frame. if we still can't schedule after 2
//frames, throw in the towel.
#ifndef TRANSPORT_RETRY_THRESHOLD
#define TRANSPORT_RETRY_THRESHOLD 8
#endif

#ifndef RRB_BW
#define RRB_BW 1
#endif

#endif
