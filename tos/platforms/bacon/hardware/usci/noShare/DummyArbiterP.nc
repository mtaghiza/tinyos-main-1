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


generic module DummyArbiterP(uint8_t default_owner_id){
  provides {
    interface Resource[uint8_t id];
    interface ResourceRequested[uint8_t id];
    interface ResourceDefaultOwner;
    interface ArbiterInfo;
  }
  uses {
    interface ResourceConfigure[uint8_t id];
    interface ResourceQueue as Queue;
    interface Leds;
  }
} implementation {
  enum {
    NO_RES = 0xFF,
  };
  norace uint8_t owner = NO_RES;

  task void grantedTask(){
    call ResourceConfigure.configure[owner]();
    signal Resource.granted[owner]();
  }

  async command error_t Resource.request[uint8_t id]() {
    if (owner == NO_RES){
      owner = id;
      post grantedTask();
      return SUCCESS;
    }else{
      return EBUSY;
    }
  } 

  async command error_t Resource.immediateRequest[uint8_t id]() {
    if (owner == NO_RES){
      owner = id;
      call ResourceConfigure.configure[owner]();
      return SUCCESS;
    }else{
      return FAIL;
    }
  }

  async command error_t Resource.release[uint8_t id]() {
    if (owner == id){
      call ResourceConfigure.unconfigure[id]();
      owner = NO_RES;
      return SUCCESS;
    }else{
      return FAIL;
    }
  }
  async command bool ArbiterInfo.inUse() {
    return (owner != NO_RES);
  }
  async command uint8_t ArbiterInfo.userId() {
    return owner;
  }
  async command bool Resource.isOwner[uint8_t id]() {
    return (owner == id);
  }

  async command error_t ResourceDefaultOwner.release() {
    return FAIL;
  }
  async command bool ResourceDefaultOwner.isOwner() {
    return FALSE;
  }
  default async event void ResourceDefaultOwner.granted() {
  }
  default async event void ResourceDefaultOwner.requested() {
    call ResourceDefaultOwner.release();
  }
  default async event void ResourceDefaultOwner.immediateRequested() {
  	call ResourceDefaultOwner.release();
  }
  default async command void ResourceConfigure.configure[uint8_t id]() {
  }
  default async command void ResourceConfigure.unconfigure[uint8_t id]() {
  }
  default event void Resource.granted[uint8_t id]() {
  }
}
