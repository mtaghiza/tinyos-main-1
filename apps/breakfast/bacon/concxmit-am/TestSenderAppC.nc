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
//originally (c) people power, adapted for modulation scheme testing on 07/11/11 by doug carlson
configuration TestSenderAppC {
} implementation {
  components TestSenderP as TestP;
  components MainC;

  TestP.Boot -> MainC;
  
  components new AMSenderC(CONCXMIT_RADIO_AM_TEST);
  TestP.RadioSend -> AMSenderC;

  components SerialActiveMessageC;
  TestP.SerialSplitControl -> SerialActiveMessageC;
  components new SerialAMSenderC(CONCXMIT_SERIAL_AM_SENDER_REPORT) as ReportSend;
  TestP.ReportSend -> ReportSend;

  components ActiveMessageC;
  TestP.SplitControl -> ActiveMessageC;
  components Rf1aActiveMessageC;
  TestP.Rf1aMulti -> Rf1aActiveMessageC;
  TestP.DelayedSendRf1aPhysical -> Rf1aActiveMessageC;
  TestP.Rf1aIf -> Rf1aActiveMessageC;


  components LedsC;
  TestP.Leds -> LedsC;

  //"use next config" to senders
  components HplMsp430InterruptC;
  components HplMsp430GeneralIOC;

  components new Msp430GpioC() as NextPin;
  NextPin.HplGeneralIO -> HplMsp430GeneralIOC.Port20;
  TestP.NextPin -> NextPin;
  components new Msp430InterruptC() as NextInterrupt;
  NextInterrupt.HplInterrupt -> HplMsp430InterruptC.Port20;
  TestP.NextInterrupt -> NextInterrupt;

  components new Msp430GpioC() as SendReadyPin;
  SendReadyPin.HplGeneralIO -> HplMsp430GeneralIOC.Port21;
  TestP.HplSendReadyPin -> HplMsp430GeneralIOC.Port21;
  //TODO: wire up so that we can select IO func. why isn't this
  //exposed through the generalIO interface?
  TestP.SendReadyPin -> SendReadyPin;
  
  components new Msp430InterruptC() as SendReadyInterrupt;
  SendReadyInterrupt.HplInterrupt -> HplMsp430InterruptC.Port21;
  TestP.SendReadyInterrupt -> SendReadyInterrupt;
  
  components new Msp430GpioC() as SendPin;
  SendPin.HplGeneralIO -> HplMsp430GeneralIOC.Port22;
  TestP.SendPin -> SendPin;

  components new Msp430InterruptC() as SendInterrupt;
  SendInterrupt.HplInterrupt -> HplMsp430InterruptC.Port22;
  TestP.SendInterrupt -> SendInterrupt;

  components new Msp430GpioC() as DebugPin;
  DebugPin.HplGeneralIO -> HplMsp430GeneralIOC.Port24;
  TestP.DebugPin -> DebugPin;

  

}
