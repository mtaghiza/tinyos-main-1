#include "SRFS7_915_GFSK_250K_SENS.h"
#include "CXConfig.h"

/*
 * Find-replaceable config. working around the lack of namespace in
 * preprocessor directives. Adapted from code (c) peoplepower.
 */
module SRFS7_915_GFSK_250K_SENS_HC {
  provides interface Rf1aConfigure;
  provides interface Get<uint16_t>;
} implementation {
  enum{ SR_COUNT = unique(SR_COUNT_KEY)};
  command uint16_t Get.get(){
    return SRFS7_915_GFSK_250K_SENS_H_GLOBAL_ID;
  }

const rf1a_config_t this_config = {
  iocfg2: 0x29,
  iocfg1: 0x06,
  iocfg0: 0x06,
  fifothr: 0x07,
  sync1: 0xd3,
  sync0: 0x91,
  pktlen: 0x3D,
  pktctrl1: 0x04,
  pktctrl0: 0x05,
  addr: 0x00,
  channr: 0x00,
  fsctrl1: 0x0C,
  fsctrl0: 0x00,
  freq2: 0x23,
  freq1: 0x31,
  freq0: 0x3B,
  mdmcfg4: 0x2D, 
  mdmcfg3: 0x3B,
  mdmcfg2: 0x13, //G-FSK
  mdmcfg1: 0x22,
  mdmcfg0: 0xf8,
  deviatn: 0x62,
  mcsm2: 0x07,
  mcsm1: 0x00,
  #ifndef RF1A_AUTOCAL
  #define RF1A_AUTOCAL 0
  #endif
  #if RF1A_AUTOCAL == 1
  mcsm0: 0x10,
  #else
  mcsm0: 0x00,
  #endif
  foccfg: 0x1D,
  bscfg: 0x1C,
  agcctrl2: 0xC7,
  agcctrl1: 0x00,
  agcctrl0: 0xB0,
  worevt1: 0x80,
  worevt0: 0x00,
  worctrl: 0xf0,
  frend1: 0xB6,
  frend0: 0x10,
  fscal3: 0xEA,
  fscal2: 0x2A,
  fscal1: 0x00,
  fscal0: 0x1F,
  // _rcctrl1 reserved
  // _rcctrl0 reserved
  fstest: 0x59,
  // ptest do not write
  // agctest do not write
  test2: 0x88,
  test1: 0x31,
  test0: 0x09,
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
  async command void Rf1aConfigure.preConfigure() { }
  async command void Rf1aConfigure.postConfigure() { }
  async command void Rf1aConfigure.preUnconfigure() { }
  async command void Rf1aConfigure.postUnconfigure() { }

}
