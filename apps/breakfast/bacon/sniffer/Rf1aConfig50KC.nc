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

#include "Rf1aConfigure.h"

module Rf1aConfig50KC{
  provides interface Rf1aConfigure;
} implementation{
  rf1a_config_t cfg = {
    iocfg2:  0x29,
    iocfg1:  0x6,
    iocfg0:  0x6,
    fifothr: 0x47,
    sync1:   0xd3,
    sync0:   0x91,
    pktlen:  0xff,
    pktctrl1:0x4,
    pktctrl0:0x5,
    addr:    0x0,
    channr:  0x0,
    fsctrl1: 0x8,
    fsctrl0: 0x0,
    freq2:   0x23,
    freq1:   0x31,
    freq0:   0x3b,
    mdmcfg4: 0x5a,
    mdmcfg3: 0xf8,
    mdmcfg2: 0x17,
    mdmcfg1: 0x22,
    mdmcfg0: 0xf8,
    deviatn: 0x47,
    mcsm2:   0x7,
    mcsm1:   0x0,
    mcsm0:   0x0,
    foccfg:  0x1d,
    bscfg:   0x1c,
    agcctrl2:0xc7,
    agcctrl1:0x0,
    agcctrl0:0xb2,
    worevt1: 0x80,
    worevt0: 0x0,
    worctrl: 0xf0,
    frend1:  0xb6,
    frend0:  0x10,
    fscal3:  0xef,
    fscal2:  0x2e,
    fscal1:  0x2b,
    fscal0:  0x1f,
    fstest:  0x59,
    test2:   0x88,
    test1:   0x31,
    test0:   0xb,
    patable: {0xc3},
  };

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return &cfg;
  }

  async command void Rf1aConfigure.preConfigure() { }
  async command void Rf1aConfigure.postConfigure() { }
  async command void Rf1aConfigure.preUnconfigure() { }
  async command void Rf1aConfigure.postUnconfigure() { }

}
