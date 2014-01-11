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


#ifndef USE_ALARM 
#define USE_ALARM 0
#endif

#ifndef USE_MICRO_TIMER
#define USE_MICRO_TIMER 0
#endif

#ifndef USE_32KHZ_TIMER
#define USE_32KHZ_TIMER 0
#endif

#ifndef TEST_BUSY 
#define TEST_BUSY 0
#endif

#if USE_SERIAL == 1
#include <stdio.h>
#else
#define printf(...)
#endif

configuration TestAppC{
} implementation {
  components MainC;
  components LedsC;

  #if USE_ALARM == 1
  #warning "using real alarm"
  components new AlarmMicro32C() as Alarm;
  #else
  #warning "using dummy alarm"
  components DummyAlarmMicro32C as Alarm;
  #endif
  
  #if USE_SERIAL == 1
  #warning "using real serial"
  components PlatformSerialC;
  components SerialPrintfC;
  #else
  #warning "using dummy serial"
  components DummyPlatformSerialC as PlatformSerialC;
  #endif

  components Msp430XV2ClockC;
  
  components new TestP(USE_ALARM,
    USE_MICRO_TIMER,
    USE_32KHZ_TIMER,
    TEST_BUSY,
    (6347UL*ALARM_MILLIS)
    + (ALARM_MILLIS/32UL)*21);
  TestP.Boot -> MainC;
  TestP.Alarm -> Alarm;
  TestP.Leds -> LedsC;
  TestP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  TestP.StdControl -> PlatformSerialC;
}
