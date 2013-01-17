#include "SRFS7_915_GFSK_0p6K_SENS.h"
#include "CXConfig.h"
/*
 * Find-replaceable config. working around the lack of namespace in
 * preprocessor directives. Adapted from code (c) peoplepower.
 */
module SRFS7_915_GFSK_0P6K_SENS_HC {
  provides interface Rf1aConfigure;
  provides interface Get<uint16_t>;
  uses interface Rf1aChannelCache;
} implementation {
  enum{ SR_COUNT = unique(SR_COUNT_KEY)};
  command uint16_t Get.get(){
    return SRFS7_915_GFSK_0P6K_SENS_H_GLOBAL_ID;
  }

const rf1a_config_t this_config = {
  iocfg2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_IOCFG2,
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_IOCFG1)
  iocfg1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_IOCFG1,
#else // IOCFG1
  iocfg1: 0x2e, // tristate
#endif // IOCFG1
  iocfg0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_IOCFG0,
  fifothr: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FIFOTHR,
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_SYNC1)
  sync1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_SYNC1,
  sync0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_SYNC0,
#else
  sync1: 0xd3,
  sync0: 0x91,
#endif
  pktlen: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_PKTLEN,
  pktctrl1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_PKTCTRL1,
  pktctrl0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_PKTCTRL0,
  addr: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_ADDR,
#ifdef USER_SETTING_CHANNR
  channr: USER_SETTING_CHANNR,
#else
  channr: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_CHANNR,
#endif
  fsctrl1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCTRL1,
  fsctrl0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCTRL0,
  freq2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FREQ2,
  freq1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FREQ1,
  freq0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FREQ0,
  mdmcfg4: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MDMCFG4,
  mdmcfg3: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MDMCFG3,
  mdmcfg2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MDMCFG2,
  mdmcfg1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MDMCFG1,
  mdmcfg0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MDMCFG0,
  deviatn: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_DEVIATN,
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MCSM2)
  mcsm2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MCSM2,
#else // MCSM2
  mcsm2: 0x07,
#endif // MCSM2
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MCSM1)
  mcsm1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MCSM1,
#else // MCSM1
  //mcsm1: 0x30,
  mcsm1: 0x00, //turn off CCA
#endif // MCSM1
  mcsm0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_MCSM0,
  foccfg: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FOCCFG,
  bscfg: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_BSCFG,
  agcctrl2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_AGCCTRL2,
  agcctrl1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_AGCCTRL1,
  agcctrl0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_AGCCTRL0,
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WOREVT1)
  worevt1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WOREVT1,
#else // WOREVT1
  worevt1: 0x80,
#endif // WOREVT1
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WOREVT0)
  worevt0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WOREVT0,
#else // WOREVT0
  worevt0: 0x00,
#endif // WOREVT0
#if defined(SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WORCTL)
  worctl: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_WORCTL,
#else // WORCTL
  worctrl: 0xf0,
#endif // WORCTL
  frend1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FREND1,
  frend0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FREND0,
  fscal3: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCAL3,
  fscal2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCAL2,
  fscal1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCAL1,
  fscal0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSCAL0,
  // _rcctrl1 reserved
  // _rcctrl0 reserved
  fstest: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_FSTEST,
  // ptest do not write
  // agctest do not write
  test2: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_TEST2,
  test1: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_TEST1,
  test0: SRFS7_915_GFSK_0P6K_SENS_H_SMARTRF_SETTING_TEST0,
    //patable (just patable0 is used), default from Rf1aConfigure.h
    #ifndef PATABLE0_SETTING
    patable: {0xc6},
    #else
    patable: {PATABLE0_SETTING},
    #endif
}; 

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return &this_config;
  }
  async command const rf1a_fscal_t* Rf1aConfigure.getFSCAL(uint8_t channel){
    return call Rf1aChannelCache.getFSCAL(channel);
  }
  async command void Rf1aConfigure.setFSCAL(uint8_t channel,
      rf1a_fscal_t fscal){
    call Rf1aChannelCache.setFSCAL(channel, fscal);
  }
  //by default, don't cache anything
  default async command const rf1a_fscal_t* Rf1aChannelCache.getFSCAL(uint8_t channel){
    return NULL;
  }
  default async command void Rf1aChannelCache.setFSCAL(uint8_t channel,
    rf1a_fscal_t fscal){ }
  async command void Rf1aConfigure.preConfigure() { }
  async command void Rf1aConfigure.postConfigure() { }
  async command void Rf1aConfigure.preUnconfigure() { }
  async command void Rf1aConfigure.postUnconfigure() { }

}
