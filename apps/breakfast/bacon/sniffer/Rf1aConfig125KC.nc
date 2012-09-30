#include "Rf1aConfigure.h"

module Rf1aConfig125KC{
  provides interface Rf1aConfigure;
} implementation{
  rf1a_config_t cfg = {
    iocfg2:  0x29,
    iocfg1:  0x6,
    iocfg0:  0x6,
    fifothr: 0x7,
    sync1:   0x91,
    sync0:   0x0,
    pktlen:  0x3d,
    pktctrl1:0x4,
    pktctrl0:0x4,
    addr:    0x0,
    channr:  TEST_CHANNEL,
    fsctrl1: 0xc,
    fsctrl0: 0x0,
    freq2:   0x23,
    freq1:   0x31,
    freq0:   0x3b,
    mdmcfg4: 0x2c,
    mdmcfg3: 0x3b,
    mdmcfg2: 0x01,
    mdmcfg1: 0x22,
    mdmcfg0: 0xf8,
    deviatn: 0x62,
    mcsm2:   0x7,
    mcsm1:   0x0,
    mcsm0:   0x0,
    foccfg:  0x1d,
    bscfg:   0x1c,
    agcctrl2:0xc7,
    agcctrl1:0x0,
    agcctrl0:0xb0,
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
