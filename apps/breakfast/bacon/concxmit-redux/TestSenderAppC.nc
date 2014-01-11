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

#include "concxmit.h"
#include <stdio.h>
//originally (c) people power, adapted for modulation scheme testing on 07/11/11 by doug carlson
configuration TestSenderAppC {
} implementation {
  components SerialPrintfC;

  components TestSenderP as TestP;
  components new TimerMilliC();
  components MainC;


  components RandomC;

  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;
  TestP.Random -> RandomC;
  
  components new DelayedAMSenderC(CONCXMIT_RADIO_AM_TEST);
  TestP.RadioSend -> DelayedAMSenderC;
  TestP.DelayedSend -> DelayedAMSenderC;

  components ActiveMessageC;
  TestP.SplitControl -> ActiveMessageC;

  components Rf1aActiveMessageC;
  TestP.Rf1aIf -> Rf1aActiveMessageC;

  components SRFS7_915_GFSK_125K_SENS_HC as TestConfigP;
  Rf1aActiveMessageC.Rf1aConfigure -> TestConfigP.Rf1aConfigure;

  components LedsC;
  TestP.Leds -> LedsC;
  
  components HplMsp430GeneralIOC;
  components HplMsp430InterruptC;

  components new Msp430GpioC() as ResetPin;
  ResetPin.HplGeneralIO -> HplMsp430GeneralIOC.Port24;
  TestP.ResetPin -> ResetPin;
  TestP.HplResetPin -> HplMsp430GeneralIOC.Port24;

  components new Msp430InterruptC() as ResetInterrupt;
  ResetInterrupt.HplInterrupt -> HplMsp430InterruptC.Port24;
  TestP.ResetInterrupt -> ResetInterrupt;

  components new Msp430GpioC() as SendPin;
  SendPin.HplGeneralIO -> HplMsp430GeneralIOC.Port11;
  TestP.SendPin -> SendPin;

  components new Msp430InterruptC() as SendInterrupt;
  SendInterrupt.HplInterrupt -> HplMsp430InterruptC.Port11;
  TestP.SendInterrupt -> SendInterrupt;

  components new Msp430GpioC() as EnablePin;
  EnablePin.HplGeneralIO -> HplMsp430GeneralIOC.Port14;
  TestP.EnablePin -> EnablePin;
  TestP.HplEnablePin -> HplMsp430GeneralIOC.Port14;

  components new Msp430InterruptC() as EnableInterrupt;
  EnableInterrupt.HplInterrupt -> HplMsp430InterruptC.Port14;
  TestP.EnableInterrupt -> EnableInterrupt;

}
