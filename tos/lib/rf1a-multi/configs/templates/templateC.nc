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

#include "INCLUDENAME"

/*
 * Find-replaceable config. working around the lack of namespace in
 * preprocessor directives. Adapted from code (c) peoplepower.
 */
module CONFIGNAMEC {
  provides interface Rf1aConfigure;
  provides interface Get<uint16_t>;
} implementation {
  command uint16_t Get.get(){
    return CONFIGNAME_GLOBAL_ID;
  }

rf1a_config_t this_config = {
  iocfg2: CONFIGNAME_SMARTRF_SETTING_IOCFG2,
#if defined(CONFIGNAME_SMARTRF_SETTING_IOCFG1)
  iocfg1: CONFIGNAME_SMARTRF_SETTING_IOCFG1,
#else // IOCFG1
  iocfg1: 0x2e, // tristate
#endif // IOCFG1
  iocfg0: CONFIGNAME_SMARTRF_SETTING_IOCFG0,
  fifothr: CONFIGNAME_SMARTRF_SETTING_FIFOTHR,
#if defined(CONFIGNAME_SMARTRF_SETTING_SYNC1)
  sync1: CONFIGNAME_SMARTRF_SETTING_SYNC1,
  sync0: CONFIGNAME_SMARTRF_SETTING_SYNC0,
#else
  sync1: 0xd3,
  sync0: 0x91,
#endif
  pktlen: CONFIGNAME_SMARTRF_SETTING_PKTLEN,
  pktctrl1: CONFIGNAME_SMARTRF_SETTING_PKTCTRL1,
  pktctrl0: CONFIGNAME_SMARTRF_SETTING_PKTCTRL0,
  addr: CONFIGNAME_SMARTRF_SETTING_ADDR,
#ifdef USER_SETTING_CHANNR
  channr: USER_SETTING_CHANNR,
#else
  channr: CONFIGNAME_SMARTRF_SETTING_CHANNR,
#endif
  fsctrl1: CONFIGNAME_SMARTRF_SETTING_FSCTRL1,
  fsctrl0: CONFIGNAME_SMARTRF_SETTING_FSCTRL0,
  freq2: CONFIGNAME_SMARTRF_SETTING_FREQ2,
  freq1: CONFIGNAME_SMARTRF_SETTING_FREQ1,
  freq0: CONFIGNAME_SMARTRF_SETTING_FREQ0,
  mdmcfg4: CONFIGNAME_SMARTRF_SETTING_MDMCFG4,
  mdmcfg3: CONFIGNAME_SMARTRF_SETTING_MDMCFG3,
  mdmcfg2: CONFIGNAME_SMARTRF_SETTING_MDMCFG2,
  mdmcfg1: CONFIGNAME_SMARTRF_SETTING_MDMCFG1,
  mdmcfg0: CONFIGNAME_SMARTRF_SETTING_MDMCFG0,
  deviatn: CONFIGNAME_SMARTRF_SETTING_DEVIATN,
#if defined(CONFIGNAME_SMARTRF_SETTING_MCSM2)
  mcsm2: CONFIGNAME_SMARTRF_SETTING_MCSM2,
#else // MCSM2
  mcsm2: 0x07,
#endif // MCSM2
#if defined(CONFIGNAME_SMARTRF_SETTING_MCSM1)
  mcsm1: CONFIGNAME_SMARTRF_SETTING_MCSM1,
#else // MCSM1
  mcsm1: 0x30,
#endif // MCSM1
  mcsm0: CONFIGNAME_SMARTRF_SETTING_MCSM0,
  foccfg: CONFIGNAME_SMARTRF_SETTING_FOCCFG,
  bscfg: CONFIGNAME_SMARTRF_SETTING_BSCFG,
  agcctrl2: CONFIGNAME_SMARTRF_SETTING_AGCCTRL2,
  agcctrl1: CONFIGNAME_SMARTRF_SETTING_AGCCTRL1,
  agcctrl0: CONFIGNAME_SMARTRF_SETTING_AGCCTRL0,
#if defined(CONFIGNAME_SMARTRF_SETTING_WOREVT1)
  worevt1: CONFIGNAME_SMARTRF_SETTING_WOREVT1,
#else // WOREVT1
  worevt1: 0x80,
#endif // WOREVT1
#if defined(CONFIGNAME_SMARTRF_SETTING_WOREVT0)
  worevt0: CONFIGNAME_SMARTRF_SETTING_WOREVT0,
#else // WOREVT0
  worevt0: 0x00,
#endif // WOREVT0
#if defined(CONFIGNAME_SMARTRF_SETTING_WORCTL)
  worctl: CONFIGNAME_SMARTRF_SETTING_WORCTL,
#else // WORCTL
  worctrl: 0xf0,
#endif // WORCTL
  frend1: CONFIGNAME_SMARTRF_SETTING_FREND1,
  frend0: CONFIGNAME_SMARTRF_SETTING_FREND0,
  fscal3: CONFIGNAME_SMARTRF_SETTING_FSCAL3,
  fscal2: CONFIGNAME_SMARTRF_SETTING_FSCAL2,
  fscal1: CONFIGNAME_SMARTRF_SETTING_FSCAL1,
  fscal0: CONFIGNAME_SMARTRF_SETTING_FSCAL0,
  // _rcctrl1 reserved
  // _rcctrl0 reserved
  fstest: CONFIGNAME_SMARTRF_SETTING_FSTEST,
  // ptest do not write
  // agctest do not write
  test2: CONFIGNAME_SMARTRF_SETTING_TEST2,
  test1: CONFIGNAME_SMARTRF_SETTING_TEST1,
  test0: CONFIGNAME_SMARTRF_SETTING_TEST0,
  /* NB: This declaration only specifies the first power level.  You
   * want to use ASK, you write your own. */
#if defined(CONFIGNAME_SMARTRF_SETTING_PATABLE0)
  patable: { CONFIGNAME_SMARTRF_SETTING_PATABLE0 },
#else
  patable: { 0xc6 }
#endif
}; 

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return &this_config;
  }
  async command void Rf1aConfigure.preConfigure() { }
  async command void Rf1aConfigure.postConfigure() { }
  async command void Rf1aConfigure.preUnconfigure() { }
  async command void Rf1aConfigure.postUnconfigure() { }

}
