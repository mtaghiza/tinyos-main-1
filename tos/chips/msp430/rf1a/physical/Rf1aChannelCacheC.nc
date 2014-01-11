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
