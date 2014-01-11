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


/**
 * Maintains a cache of channel:FSCAL1/2/3 settings.
 * 
 * For Rf1aConfigure modules which don't want to support caching,
 * here's the stubs:

  async command const rf1a_fscal_t* Rf1aConfigure.getFSCAL(uint8_t channel){
    return call Rf1aChannelCache.getFSCAL(channel);
  }
  async command void Rf1aConfigure.setFSCAL(uint8_t channel,
      rf1a_fscal_t fscal){
    call Rf1aChannelCache.setFSCAL(channel, fscal);
  }
  default async command const rf1a_fscal_t* Rf1aChannelCache.getFSCAL(uint8_t channel){ return NULL; }
  default async command void Rf1aChannelCache.setFSCAL(uint8_t channel,
    rf1a_fscal_t fscal){ }

 */
interface Rf1aChannelCache{
  async command const rf1a_fscal_t* getFSCAL(uint8_t channel);
  async command void setFSCAL(uint8_t channel, rf1a_fscal_t fscal);
}
