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

#include "radioTest.h"

configuration TestAppC{
} implementation {
  components TestP;

  components MainC, LedsC, new TimerMilliC();
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;
  TestP.Timer -> TimerMilliC;
  components new TimerMilliC() as IndicatorTimer;
  TestP.IndicatorTimer -> IndicatorTimer;
  components new TimerMilliC() as StartupTimer;
  TestP.StartTimer -> StartupTimer;

  components WatchDogC;

  components PlatformSerialC;
  components SerialPrintfC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  components ActiveMessageC;
//  components new DelayedAMSenderC(AM_RADIO_TEST) as AMSenderC;
  components new AMSenderC(AM_RADIO_TEST) as AMSenderC;
  components new AMReceiverC(AM_RADIO_TEST);
  TestP.SplitControl -> ActiveMessageC;
  TestP.AMSend -> AMSenderC;
//  TestP.DelayedSend -> AMSenderC;
  TestP.AMPacket -> AMSenderC;
  TestP.Packet -> AMSenderC;
  TestP.Receive -> AMReceiverC;

  components Rf1aActiveMessageC;
  //for setting tx power
  TestP.Rf1aIf -> Rf1aActiveMessageC;
  TestP.Rf1aPhysical -> Rf1aActiveMessageC;

  components Rf1aDumpConfigC;
  TestP.Rf1aDumpConfig -> Rf1aDumpConfigC;

  components CC1190C;
  TestP.AmpControl -> CC1190C;
  TestP.CC1190 -> CC1190C;
  
  //TODO: swap settings at compile time. Include in settings (for
  //  logging)
  //SRFS6_868_xxx_CUR_HC.nc
//  components PDERf1aSettingsP as TestConfigP;
  components SRFS7_915_GFSK_125K_SENS_HC as TestConfigP;
//  components DefaultRf1aSettingsP as TestConfigP;
//
//  components new Rf1aChannelCacheC(2);
//  TestConfigP.Rf1aChannelCache -> Rf1aChannelCacheC;
  Rf1aActiveMessageC.Rf1aConfigure -> TestConfigP.Rf1aConfigure;

  components Rf1aC;
  TestP.Rf1aPhysicalMetadata -> Rf1aC.Rf1aPhysicalMetadata;
}
