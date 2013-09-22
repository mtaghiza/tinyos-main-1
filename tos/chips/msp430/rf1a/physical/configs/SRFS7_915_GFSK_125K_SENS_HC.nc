#include "Rf1aConfigure.h"
#ifndef RF1A_AUTOCAL
#define RF1A_AUTOCAL 0
#endif

#ifndef RF1A_WHITENING_ENABLED
#define RF1A_WHITENING_ENABLED 1
#endif

module SRFS7_915_GFSK_125K_SENS_HC{
  provides interface Rf1aConfigure;
  uses interface Rf1aChannelCache;
} implementation{
  const rf1a_config_t cfg = {
    iocfg2:  0x29,   
    
    iocfg1:  0x06,//SFD send/receive
    iocfg0:  0x06,//SFD send/receive
    fifothr: 0x07,   
    
    sync1:   0xd3,
    
    sync0:   0x91,
    pktlen:  0xff,    
    pktctrl1:0x04,   
    #if RF1A_WHITENING_ENABLED == 1
    pktctrl0:0x45,   
    #else
    #warning Disable packet whitening
    pktctrl0:0x05,   
    #endif
    addr:    0x00,   
    channr:  0,   
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

    #if RF1A_AUTOCAL == 1
    #warning "Using auto-calibration"
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
    patable: {0xc3},
    #else
    patable: {PATABLE0_SETTING},
    #endif
};

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return &cfg;
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
