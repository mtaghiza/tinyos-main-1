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

#ifndef PLATFORM_MESSAGE_H
#define PLATFORM_MESSAGE_H

#ifndef TOSH_DATA_LENGTH
//The maximum packet we can send with FEC is 127 bytes (2x packet len
//< 255). The link header is 10 bytes long, so the longest DL is 117.
//By setting this to 110, we give ourselves a little breathing room in
//case we end up having to extend the header (e.g. to put in
//timestamp information)
#define TOSH_DATA_LENGTH 110
#endif

#include "CXLink.h"
#include "Rf1aPacket.h"
#include "Serial.h"

typedef union message_header {
  cx_link_header_t cx_link_header;
  serial_header_t serial_header;
} __attribute__((packed)) message_header_t;

typedef struct TOSRadioFooter {
  nx_uint8_t paddingByte;
  nx_uint16_t checksum;
} message_footer_t;

typedef struct TOSRadioMetadata {
  cx_link_metadata_t cx;
  rf1a_metadata_t rf1a;
} message_metadata_t;
#endif
