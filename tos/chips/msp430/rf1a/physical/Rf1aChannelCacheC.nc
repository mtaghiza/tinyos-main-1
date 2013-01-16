
 #include "Rf1aConfigure.h"

generic module Rf1aChannelCacheC(uint8_t cacheSize){
  provides interface Rf1aChannelCache;
} implementation {
  rf1a_fscal_t channelCache[cacheSize];
  uint8_t next = 0;
  uint8_t numValid = 0;
  
  rf1a_fscal_t* findEntry(uint8_t channel){
    uint8_t i;
    for ( i = 0; i < numValid; i++){
      if (channelCache[i].channr == channel){
        return &(channelCache[i]);
      }
    }
    return NULL;
  }
  //the cache should be pretty small, so just do a sequential search
  //through it.
  async command const rf1a_fscal_t* Rf1aChannelCache.getFSCAL(uint8_t channel){
    return findEntry(channel);
  }
  
  //use dumb round-robin eviction-- in general we're going to know how
  //roughly many channels we will use at compile time, so it's not
  //worth doing an LRU-type of algorithm.
  async command void Rf1aChannelCache.setFSCAL(uint8_t channel, rf1a_fscal_t fscal){
    rf1a_fscal_t * entry = findEntry(channel);

    fscal.channr = channel;
    if (entry != NULL){
      *entry = fscal;
    }else{
      channelCache[next] = fscal;
      next = (next + 1) % cacheSize;
      numValid = (numValid < cacheSize)? numValid + 1: cacheSize;
    }
  }
}
