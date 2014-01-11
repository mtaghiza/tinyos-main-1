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

#ifndef TEST_H
#define TEST_H
#include "CXDebug.h"

#define AM_TEST_MSG 0xD0
#ifndef DESTINATION_ID 
#define DESTINATION_ID 0x00
#endif

#ifndef DL_test
#define DL_test DL_INFO
#endif

#ifndef PAYLOAD_LEN
#define PAYLOAD_LEN 50
#endif

typedef nx_struct test_payload {
  nx_uint8_t buffer[PAYLOAD_LEN];
  nx_uint32_t timestamp;
  nx_uint32_t sn;
} test_payload_t;

#ifndef SEND_THRESHOLD
#define SEND_THRESHOLD 1
#endif

#ifndef TEST_STARTUP_DELAY
#define TEST_STARTUP_DELAY (60UL*1024UL)
#endif

#ifndef TEST_DESTINATION
#define TEST_DESTINATION AM_BROADCAST_ADDR
#endif

#ifndef TEST_IPI 
#define TEST_IPI (60UL*1024UL)
#endif

#ifndef TEST_RANDOMIZE
#define TEST_RANDOMIZE (10UL*1024UL)
#endif

#ifndef TEST_TRANSMIT
#define TEST_TRANSMIT 0
#endif

#ifndef SCHEDULED_TEST
#define SCHEDULED_TEST 0
#endif

#ifndef TEST_FRAME_BASE 
#define TEST_FRAME_BASE 0
#endif

#ifndef TEST_FRAME_RANGE
#define TEST_FRAME_RANGE 100
#endif

#endif
