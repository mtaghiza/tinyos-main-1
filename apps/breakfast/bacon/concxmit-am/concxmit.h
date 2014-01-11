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

#ifndef CONCXMIT_H
#define CONCXMIT_H

#define CONCXMIT_RADIO_AM_TEST 0xDC

#define CONCXMIT_SERIAL_AM_CMD 0xDC
#define CONCXMIT_SERIAL_AM_RECEIVER_REPORT 0xDD
#define CONCXMIT_SERIAL_AM_SENDER_REPORT 0xDE

typedef nx_struct {
  nx_uint16_t seqNum;
} test_packet_t;

#define CONCXMIT_CMD_NEXT 0x01
#define CONCXMIT_CMD_SEND 0x02

//Power levels
//-12   -6      0       10
//0x25  0x2D    0x8D    0xC3

#define TX_POWER_1 0x25
#define TX_POWER_2 0x8D

typedef nx_struct {
  nx_uint8_t cmd;
  nx_uint16_t send1Offset;
  nx_uint16_t sendCount;
} cmd_t;

typedef nx_struct{
  nx_uint16_t configId;
  nx_uint16_t seqNum;
  nx_uint8_t received;
  nx_uint16_t rssi;
  nx_uint16_t lqi;
  nx_uint16_t send1Offset;
} receiver_report_t;

typedef nx_struct{
  nx_uint16_t configId;
  nx_uint16_t seqNum;
} sender_report_t;

#define SEND_TIMEOUT 256

#endif
