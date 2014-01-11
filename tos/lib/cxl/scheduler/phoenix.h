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

#ifndef PHOENIX_H
#define PHOENIX_H

#define SS_KEY_PHOENIX_SAMPLE_INTERVAL 0x16 
#define SS_KEY_PHOENIX_TARGET_REFS 0x17 

#define RECORD_TYPE_PHOENIX 0x16

#ifndef DEFAULT_PHOENIX_TARGET_REFS
#define DEFAULT_PHOENIX_TARGET_REFS 1
#endif

#ifndef DEFAULT_PHOENIX_SAMPLE_INTERVAL
#define DEFAULT_PHOENIX_SAMPLE_INTERVAL (1024UL * 60UL * 60UL * 8UL)
#endif


#ifndef MAX_WASTED_SNIFFS
#define MAX_WASTED_SNIFFS 2
#endif

typedef struct phoenix_reference {
  uint8_t recordType;
  am_addr_t node2;
  uint16_t rc1;
  uint16_t rc2;
  uint32_t localTime1;
  uint32_t localTime2;
} __attribute__((packed)) phoenix_reference_t;

#endif
