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

generic configuration I2CDiscoverableC(){
  provides interface I2CDiscoverable;
  provides interface Resource;
  provides interface I2CSlave;
  provides interface I2CPacket<TI2CBasicAddr>;
} implementation {
  components new Msp430UsciI2CB0C() as Msp430I2C0C;
  components new TimerMilliC() as RandomizeTimer;
  components RandomC;

  components new I2CDiscoverableRequesterP() as I2CDiscoverableP;
  I2CDiscoverableP.SubI2CPacket -> Msp430I2C0C;
  I2CDiscoverableP.SubI2CSlave -> Msp430I2C0C;
  I2CDiscoverableP.SubResource -> Msp430I2C0C;
  I2CDiscoverableP.RandomizeTimer -> RandomizeTimer;
  I2CDiscoverableP.Random -> RandomC;
  I2CDiscoverableP.RandomInit -> RandomC.SeedInit;
  Msp430I2C0C.Msp430UsciConfigure -> I2CDiscoverableP.Msp430UsciConfigure;
  
  I2CDiscoverable = I2CDiscoverableP;
  Resource = I2CDiscoverableP.Resource;
  I2CSlave = I2CDiscoverableP.I2CSlave;
  I2CPacket = I2CDiscoverableP.I2CPacket;
}
