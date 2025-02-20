#include "SRFS6_868_GFSK_175K_CUR.h"

/*
 * Find-replaceable config. working around the lack of namespace in
 * preprocessor directives. Adapted from code (c) peoplepower.
 */
module SRFS6_868_GFSK_175K_CUR_HC {
  provides interface Rf1aConfigure;
  provides interface Get<uint16_t>;
} implementation {
  command uint16_t Get.get(){
    return SRFS6_868_GFSK_175K_CUR_H_GLOBAL_ID;
  }

rf1a_config_t this_config = {
  iocfg2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_IOCFG2,
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_IOCFG1)
  iocfg1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_IOCFG1,
#else // IOCFG1
  iocfg1: 0x2e, // tristate
#endif // IOCFG1
  iocfg0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_IOCFG0,
  fifothr: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FIFOTHR,
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_SYNC1)
  sync1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_SYNC1,
  sync0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_SYNC0,
#else
  sync1: 0xd3,
  sync0: 0x91,
#endif
  pktlen: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_PKTLEN,
  pktctrl1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_PKTCTRL1,
  pktctrl0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_PKTCTRL0,
  addr: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_ADDR,
#ifdef USER_SETTING_CHANNR
  channr: USER_SETTING_CHANNR,
#else
  channr: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_CHANNR,
#endif
  fsctrl1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCTRL1,
  fsctrl0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCTRL0,
  freq2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FREQ2,
  freq1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FREQ1,
  freq0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FREQ0,
  mdmcfg4: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MDMCFG4,
  mdmcfg3: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MDMCFG3,
  mdmcfg2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MDMCFG2,
  mdmcfg1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MDMCFG1,
  mdmcfg0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MDMCFG0,
  deviatn: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_DEVIATN,
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MCSM2)
  mcsm2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MCSM2,
#else // MCSM2
  mcsm2: 0x07,
#endif // MCSM2
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MCSM1)
  mcsm1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MCSM1,
#else // MCSM1
  mcsm1: 0x30,
#endif // MCSM1
  mcsm0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_MCSM0,
  foccfg: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FOCCFG,
  bscfg: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_BSCFG,
  agcctrl2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_AGCCTRL2,
  agcctrl1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_AGCCTRL1,
  agcctrl0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_AGCCTRL0,
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WOREVT1)
  worevt1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WOREVT1,
#else // WOREVT1
  worevt1: 0x80,
#endif // WOREVT1
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WOREVT0)
  worevt0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WOREVT0,
#else // WOREVT0
  worevt0: 0x00,
#endif // WOREVT0
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WORCTL)
  worctl: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_WORCTL,
#else // WORCTL
  worctrl: 0xf0,
#endif // WORCTL
  frend1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FREND1,
  frend0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FREND0,
  fscal3: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCAL3,
  fscal2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCAL2,
  fscal1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCAL1,
  fscal0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSCAL0,
  // _rcctrl1 reserved
  // _rcctrl0 reserved
  fstest: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_FSTEST,
  // ptest do not write
  // agctest do not write
  test2: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_TEST2,
  test1: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_TEST1,
  test0: SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_TEST0,
  /* NB: This declaration only specifies the first power level.  You
   * want to use ASK, you write your own. */
#if defined(SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_PATABLE0)
  patable: { SRFS6_868_GFSK_175K_CUR_H_SMARTRF_SETTING_PATABLE0 },
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
