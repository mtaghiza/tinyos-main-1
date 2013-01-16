
 #include "Rf1aConfigure.h"

generic module Rf1aChannelCacheC(uint8_t cacheSize){
  provides interface Rf1aChannelCache;
} implementation {
  rf1a_fscal_t channelCache[cacheSize];
  uint8_t next = 0;
  uint8_t numValid = 0;
  
  //the cache should be pretty small, so just do a sequential search
  //through it.
  async command const rf1a_fscal_t* Rf1aChannelCache.getFSCAL(uint8_t channel){
    uint8_t i;
    for ( i = 0; i < numValid; i++){
      if (channelCache[i].channr == channel){
        printf("%u cached@ %u\r\n", channel, i);
        return &(channelCache[i]);
      }
    }
    return NULL;
  }
  
  //use dumb round-robin eviction-- in general we're going to know how
  //roughly many channels we will use at compile time, so it's not
  //worth doing an LRU-type of algorithm.
  async command void Rf1aChannelCache.setFSCAL(uint8_t channel, rf1a_fscal_t fscal){
    uint8_t i;
    fscal.channr = channel;
    for(i = 0; i < numValid; i++){
      if(channelCache[i].channr == channel){
        printf("update cache[%u]: %u %x %x %x\r\n", 
          next, fscal.channr, fscal.fscal1, fscal.fscal2, 
          fscal.fscal3);
        channelCache[i] = fscal;
        return;
      }
    }
    channelCache[next] = fscal;
    printf("write cache[%u]: %u %x %x %x\r\n", 
      next, fscal.channr, fscal.fscal1, fscal.fscal2, 
      fscal.fscal3);
    next = (next + 1) % cacheSize;
    numValid = (numValid < cacheSize)? numValid + 1: cacheSize;
  }
}
