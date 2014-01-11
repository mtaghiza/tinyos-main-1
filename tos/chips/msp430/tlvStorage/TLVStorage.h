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

#ifndef TLVSTORAGE_H
#define TLVSTORAGE_H

#define TLV_UTILS_CLIENT "TLVUtilsClient"

#define TAG_VERSION    (0x02)
#define TAG_DCO_CUSTOM (0x03)
//flag value for "match any tag"
#define TAG_ANY        (0x00)

//See msp430f235.h for TAG_DCO_30, TAG_ADC12_1, TAG_EMPTY, and other
//  constants. OK, the cc430f5137 uses different conventions, awesome.
#ifndef TAG_EMPTY
#define TAG_EMPTY (0xfe)
#endif
#ifndef TAG_DCO_30
#define TAG_DCO_30 (0x01)
#endif
#ifndef TAG_ADC12_1
#define TAG_ADC12_1 (0x08)
#endif

#define TLV_CHECKSUM_LENGTH 2

//#ifndef TLV_LEN
//#define TLV_LEN 64
//#endif

typedef struct {
  uint8_t tag;
  uint8_t len;
  union{
    uint8_t b[0];
    uint16_t w[0];
  } data;
} __attribute__((__packed__)) tlv_entry_t;

typedef struct{
  tlv_entry_t header;
  uint16_t version;
} __attribute__((__packed__)) version_entry_t;

typedef struct{
  tlv_entry_t header;
  uint8_t bcsctl1;
  uint8_t dcoctl;
} __attribute__((__packed__)) custom_dco_entry_t;
#endif
