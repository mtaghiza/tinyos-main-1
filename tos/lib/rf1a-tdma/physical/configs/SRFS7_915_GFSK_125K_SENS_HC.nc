#include "Rf1aConfigure.h"
#include "CXConfig.h"
#ifndef TEST_CHANNEL
#define TEST_CHANNEL 0x00
#endif
module SRFS7_915_GFSK_125K_SENS_HC{
  provides interface Rf1aConfigure;
} implementation{
  enum{ SR_COUNT = unique(SR_COUNT_KEY)};
  const rf1a_config_t cfg = {
    iocfg2:  0x29,   
    
    iocfg1:  0x06,   
    iocfg0:  0x06,   
    fifothr: 0x07,   
    
    sync1:   0xd3,
    
    sync0:   0x91,
    pktlen:  0x3D,    
    pktctrl1:0x04,   
    pktctrl0:0x05,   
    addr:    0x00,   
    channr:  TEST_CHANNEL,   
    fsctrl1: 0x0C,   
    fsctrl0: 0x00,   
    freq2:   0x23,   
    freq1:   0x31,   
    freq0:   0x3B,   
    mdmcfg4: 0x2C,   
    mdmcfg3: 0x3B,   
    mdmcfg2: 0x03,   
    mdmcfg1: 0x22,   
    mdmcfg0: 0xF8,   
    deviatn: 0x62,   
    
    mcsm2:   0x07,
    
    mcsm1:   0x00,
    #ifndef RF1A_AUTOCAL
    #define RF1A_AUTOCAL 0
    #endif
    #if RF1A_AUTOCAL == 1
    mcsm0:   0x10,   
    #else
    mcsm0:   0x00,   
    #endif
    foccfg:  0x1D,   
    bscfg:   0x1C,   
    agcctrl2:0xC7,   
    agcctrl1:0x00,   
    agcctrl0:0xB0,   
    
    worevt1: 0x80,
    
    worevt0: 0x00,
    
    worctrl: 0xf0,
    frend1:  0xB6,   
    frend0:  0x10,   
    fscal3:  0xEA,   
    fscal2:  0x2A,   
    fscal1:  0x00,   
    fscal0:  0x1F,   
    
    
    fstest:  0x59,   
    
    
    test2:   0x88,   
    test1:   0x31,   
    test0:   0x09,   
    
    #ifndef PATABLE0_SETTING
    patable: {0xc6},
    #else
    patable: {PATABLE0_SETTING},
    #endif
};

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return &cfg;
  }

  async command void Rf1aConfigure.preConfigure() { }
  async command void Rf1aConfigure.postConfigure() { }
  async command void Rf1aConfigure.preUnconfigure() { }
  async command void Rf1aConfigure.postUnconfigure() { }

}
