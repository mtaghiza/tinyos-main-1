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

generic configuration HplMsp430Rf1aFECP() {
  provides interface ResourceConfigure[uint8_t client];
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aStatus;
  provides interface Rf1aPhysicalMetadata;
  provides interface DelayedSend[uint8_t client];

  
  uses interface ArbiterInfo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
  uses interface Rf1aConfigure[uint8_t client];
  uses interface Rf1aTransmitFragment[uint8_t client];
  uses interface Rf1aInterrupts[uint8_t client];
  uses interface Leds;
  
  //These go to HplMsp430Rf1aP
  uses interface Rf1aTransmitFragment as DefaultRf1aTransmitFragment;
  uses interface SetNow<uint8_t> as DefaultLength;
  uses interface SetNow<const uint8_t*> as DefaultBuffer;
} implementation {
  components new Rf1aFECC();
  
  components new HplMsp430Rf1aP() as HplRf1aP;
  HplRf1aP.Rf1aIf = Rf1aIf;
  HplRf1aP.ArbiterInfo = ArbiterInfo;
  Rf1aPhysicalMetadata = HplRf1aP;
  Rf1aStatus = HplRf1aP;
  Rf1aConfigure = HplRf1aP;
  ResourceConfigure = HplRf1aP;

  HplRf1aP.Rf1aInterrupts = Rf1aInterrupts;
  HplRf1aP.Leds = Leds;

  Rf1aPhysical = Rf1aFECC;
  Rf1aFECC.SubRf1aPhysical -> HplRf1aP;
  HplRf1aP.Rf1aTransmitFragment -> Rf1aFECC.SubRf1aTransmitFragment;

  Rf1aTransmitFragment = Rf1aFECC.Rf1aTransmitFragment;
  DelayedSend = HplRf1aP.DelayedSend;

  HplRf1aP.DefaultRf1aTransmitFragment = DefaultRf1aTransmitFragment;
  HplRf1aP.DefaultLength = DefaultLength;
  HplRf1aP.DefaultBuffer = DefaultBuffer;
}
