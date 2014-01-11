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

#ifndef HARDWARE_H
#define HARDWARE_H

#include "msp430hardware.h"

//Backwards compatibility with mspgcc4
// also, these are easier to read.
#define TASSEL_TACLK TASSEL_0
#define TASSEL_ACLK  TASSEL_1
#define TASSEL_SMCLK TASSEL_2
#define TASSEL_INCLK TASSEL_3

#define TBSSEL_TBCLK TBSSEL_0
#define TBSSEL_ACLK  TBSSEL_1
#define TBSSEL_SMCLK TBSSEL_2
#define TBSSEL_INCLK TBSSEL_3

#define ID_DIV1 ID_0
#define ID_DIV2 ID_1
#define ID_DIV4 ID_2
#define ID_DIV8 ID_3

#define UCSSEL_UCLK  UCSSEL_0
#define UCSSEL_UCLKI UCSSEL_0
#define UCSSEL_ACLK  UCSSEL_1
#define UCSSEL_SMCLK UCSSEL_2

#define UCMODE_UART UCMODE_0
#define UCMODE_SPI3 UCMODE_0
#define UCMODE_SPI4H UCMODE_1
#define UCMODE_SPI4L UCMODE_2
#define UCMODE_I2C UCMODE_3

#endif
