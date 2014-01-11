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

#include "I2CDiscoverable.h"
generic configuration I2CDiscovererC(){
  provides interface I2CDiscoverer;
} implementation {
  components new BaconI2CB0C() as Msp430I2C0C;
  components new TimerMilliC();
  components new QueueC(discoverer_register_union_t*, I2C_DISCOVERY_POOL_SIZE);
  components new PoolC(discoverer_register_union_t, I2C_DISCOVERY_POOL_SIZE);

  components new I2CDiscovererP() as I2CDiscovererP;
  I2CDiscovererP.I2CPacket -> Msp430I2C0C;
  I2CDiscovererP.I2CSlave -> Msp430I2C0C;
  I2CDiscovererP.Resource -> Msp430I2C0C;
  I2CDiscovererP.Timer -> TimerMilliC;
  I2CDiscovererP.Queue -> QueueC;
  I2CDiscovererP.Pool -> PoolC;
  Msp430I2C0C.Msp430UsciConfigure -> I2CDiscovererP.Msp430UsciConfigure;
  
  I2CDiscoverer = I2CDiscovererP;
}
