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

#ifndef BASESTATION_H
#define BASESTATION_H

#include "AM.h"
#include "message.h"

typedef struct queue_entry {
  message_t* msg;
  void* pl;
  uint8_t len;
} queue_entry_t;

typedef nx_struct cx_download_started{
  nx_uint8_t error;
} cx_download_started_t;

typedef nx_struct fwd_status{
  nx_uint8_t queueCap;
} fwd_status_t;

typedef nx_struct cx_download_finished {
  nx_uint8_t networkSegment;
} cx_download_finished_t;

//typedef nx_struct status_time_ref {
//  nx_am_addr_t node;
//  nx_uint16_t rc;
//  nx_uint32_t ts;
//} status_time_ref_t;

typedef nx_struct identify_request {
  nx_uint8_t dummy;
} identify_request_t;

typedef nx_struct identify_response {
  nx_am_addr_t self;
} identify_response_t;

typedef nx_struct cx_eos_report {
  nx_am_addr_t owner;
  nx_uint8_t status;
} cx_eos_report_t;

enum {
  AM_CX_DOWNLOAD_FINISHED=0xD1,
  AM_CX_DOWNLOAD_STARTED=0xD2,
  AM_IDENTIFY_REQUEST=0xD4,
  AM_IDENTIFY_RESPONSE=0xD5,
  AM_FWD_STATUS=0xD6,
  AM_CX_EOS_REPORT = 0xD7,
};

#endif
