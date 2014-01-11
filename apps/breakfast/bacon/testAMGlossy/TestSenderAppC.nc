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

#include <stdio.h>
configuration TestSenderAppC {
} implementation {
  components SerialPrintfC;

  components TestSenderP as TestP;
  components new TimerMilliC();
  components MainC;

  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;
  components new AMGlossyC(0xDD);  

  TestP.RadioSend -> AMGlossyC;
  TestP.Receive -> AMGlossyC;

  components ActiveMessageC;
  TestP.SplitControl -> ActiveMessageC;

  components Rf1aActiveMessageC;
  TestP.Rf1aPhysical -> Rf1aActiveMessageC;
  TestP.HplMsp430Rf1aIf -> Rf1aActiveMessageC;

  //Switch at compile time if desired
  #if RF1A_BAUD == 500000
  components GlossyRf1aSettings500KC as Rf1aSettings;
  #elif RF1A_BAUD == 250000 
  components GlossyRf1aSettings250KC as Rf1aSettings;
  #elif RF1A_BAUD == 125000
  components GlossyRf1aSettings125KC as Rf1aSettings;
  #elif RF1A_BAUD == 1200
  components GlossyRf1aSettings1P2KC as Rf1aSettings;
  #else 
  #warning RF1A_BAUD not defined or recognized, using 250K
  components GlossyRf1aSettings250KC as Rf1aSettings;
  #endif

  Rf1aActiveMessageC.Rf1aConfigure -> Rf1aSettings;

  components LedsC;
  TestP.Leds -> LedsC;

  components PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
  
  components Rf1aDumpConfigC;
  TestP.Rf1aConfigure -> Rf1aSettings;
  TestP.Rf1aDumpConfig -> Rf1aDumpConfigC;
}
