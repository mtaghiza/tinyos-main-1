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

#ifndef CX_NETWORK_H
#define CX_NETWORK_H

typedef nx_struct cx_network_header {
  nx_uint8_t ttl;
  nx_uint8_t hops;
  nx_uint16_t sn;
} cx_network_header_t;

typedef struct cx_network_metadata {
  uint8_t layerCount;
  uint32_t reqFrame;
  uint32_t microRef;
  uint32_t t32kRef;
  nx_uint32_t* tsLoc;
  void* next;
} cx_network_metadata_t;

#ifndef CX_NETWORK_POOL_SIZE
//1 for forwarding, 1 for self. Expand if we ever support multiple
//  ongoing floods.
#define CX_NETWORK_POOL_SIZE 5
#endif

#ifndef CX_NETWORK_FORWARD_DELAY 
//forward received packet immediately.
#define CX_NETWORK_FORWARD_DELAY 1
#endif

#ifndef CX_SELF_RETX
#define CX_SELF_RETX 0
#endif

#define INVALID_TIMESTAMP 0xFFFFFFFF

#ifndef MAX_SOFT_SYNCH 
#define MAX_SOFT_SYNCH 1
#endif

#endif
