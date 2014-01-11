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

generic module Rf1aMultiPhysicalP (char configSetIdentifier[]){
  provides interface Rf1aConfigure;
  provides interface Rf1aMulti;
  uses interface Rf1aConfigure as SubConfigure[uint8_t clientId] ;
  uses interface Get<uint16_t> as SubGet[uint8_t clientId];
} implementation {
  uint8_t currentClient = 0;

  command uint8_t Rf1aMulti.getNumConfigs(){
    return uniqueCount(configSetIdentifier);
  }

  command uint8_t Rf1aMulti.getConfig(){
    return currentClient;
  }

  command error_t Rf1aMulti.setConfig(uint8_t clientId){
    if(clientId > uniqueCount(configSetIdentifier)){
      return EINVAL;
    } else {
      atomic{
        currentClient = clientId;
      }
      //TODO: this should check for safety first
      return SUCCESS;
    }
  }

  command error_t Rf1aMulti.setConfigId(uint16_t id){
    uint8_t k;
    error_t rv;
    for(k = 0; k < (call Rf1aMulti.getNumConfigs()); k++){
      if( call SubGet.get[k]() == id){
        rv = call Rf1aMulti.setConfig(k);
        return rv;
      }
    }
    return EINVAL;
  }

  command uint16_t Rf1aMulti.getConfigId(){
    return call SubGet.get[currentClient]();
  }

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    return call SubConfigure.getConfiguration[currentClient]();
  }
  async command void Rf1aConfigure.preConfigure(){
    call SubConfigure.preConfigure[currentClient]();
  }
  async command void Rf1aConfigure.postConfigure(){
    call SubConfigure.postConfigure[currentClient]();
  }
  async command void Rf1aConfigure.preUnconfigure(){
    call SubConfigure.preUnconfigure[currentClient]();
  }
  async command void Rf1aConfigure.postUnconfigure(){
    call SubConfigure.postUnconfigure[currentClient]();
  }

  default async command const rf1a_config_t* SubConfigure.getConfiguration[uint8_t clientId](){
    return NULL;
  }
  default command uint16_t SubGet.get[uint8_t clientId](){ return 0xFFFF;}
  default async command void SubConfigure.preConfigure[uint8_t clientId](){ }
  default async command void SubConfigure.postConfigure[uint8_t clientId](){ } 
  default async command void SubConfigure.preUnconfigure[uint8_t clientId](){ } 
  default async command void SubConfigure.postUnconfigure[uint8_t clientId](){ }
}
