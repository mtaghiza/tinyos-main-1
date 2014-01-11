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

#ifndef I2C_DISCOVERABLE_H
#define I2C_DISCOVERABLE_H

#include "GlobalID.h"

#define I2C_DISCOVERY_INITIAL_TIMEOUT 30*1024
#define I2C_DISCOVERY_ROUND_TIMEOUT 512
#define I2C_RANDOMIZE_MAX_DELAY 256
#define I2C_DISCOVERY_POOL_SIZE 10

#define I2C_INVALID_MASTER 0xffff
#define I2C_DISCOVERABLE_UNASSIGNED 0xfffe

#define I2C_FIRST_DISCOVERABLE_ADDR 0x0040
#define I2C_GC_ADDR 0x00
#define I2C_DISCOVERABLE_REQUEST_ADDR 0xad

#define I2C_GC_PROGRAM_ADDR 0x04
#define I2C_GC_RESET_PROGRAM_ADDR 0x06

  typedef struct {
    uint8_t cmd;
    uint8_t globalAddr[GLOBAL_ID_LEN];
    uint16_t localAddr;
    uint8_t padding[5];
  } __attribute__((__packed__)) discoverer_register_t;

  typedef union{
    discoverer_register_t val;
    uint8_t data[sizeof(discoverer_register_t)];
  } __attribute__((__packed__)) discoverer_register_union_t;

#endif
