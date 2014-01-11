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

#ifndef RECORD_STORAGE_H
#define RECORD_STORAGE_H

#include "message.h"


#ifndef LOG_RECORD_HEADER_SPACE
#define LOG_RECORD_HEADER_SPACE 0
#endif


//most efficient way to pack them in, hope byte alignment isn't too
//much trouble.
typedef nx_struct log_record_t {
  nx_uint32_t cookie;
  nx_uint8_t length;
  nx_uint8_t data[0];
} __attribute__((packed)) log_record_t;

#ifndef MAX_RECORD_PACKET_LEN
//give some breathing room in case we add more headers to packet.
#define MAX_RECORD_PACKET_LEN (TOSH_DATA_LENGTH - 8 - sizeof(log_record_t) - LOG_RECORD_HEADER_SPACE )
#endif
//this is going to be a bunch of variable-length records, so all we
//can do is give it a flat buffer.
typedef nx_struct log_record_data_msg {
  nx_uint16_t length;
  nx_uint32_t nextCookie;
  nx_uint8_t data[0];
} __attribute__((packed)) log_record_data_msg_t;

enum {
  AM_LOG_RECORD_DATA_MSG = 0xE0,
};

#endif
