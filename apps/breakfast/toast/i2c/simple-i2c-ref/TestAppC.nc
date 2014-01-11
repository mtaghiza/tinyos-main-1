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

#include "msp430usart.h"
configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components LedsC;
  //components new Msp430I2CC() as I2C;
  components new TimerMilliC();
  //components PlatformSerialC;
  components new Msp430I2CC();

  components new Msp430GpioC() as Pin0;
  components new Msp430GpioC() as Pin1;
  components new Msp430GpioC() as Pin2;
  components new Msp430GpioC() as Pin3;
  components HplMsp430GeneralIOC;
  Pin0.HplGeneralIO -> HplMsp430GeneralIOC.Port60;
  Pin1.HplGeneralIO -> HplMsp430GeneralIOC.Port61;
  Pin2.HplGeneralIO -> HplMsp430GeneralIOC.Port62;
  Pin3.HplGeneralIO -> HplMsp430GeneralIOC.Port63;

  TestP.Boot -> MainC.Boot;
  TestP.Leds -> LedsC;
  TestP.Timer -> TimerMilliC;
  TestP.Pin0 -> Pin0;
  TestP.Pin1 -> Pin1;
  TestP.Pin2 -> Pin2;
  TestP.Pin3 -> Pin3;

  TestP.Resource -> Msp430I2CC.Resource;
  TestP.ResourceRequested -> Msp430I2CC.ResourceRequested;
  TestP.I2CBasicAddr -> Msp430I2CC.I2CBasicAddr;
  Msp430I2CC.Msp430I2CConfigure -> TestP.Msp430I2CConfigure;

//  TestP.UartControl -> PlatformSerialC;
//  TestP.UartStream -> PlatformSerialC;
//  TestP.UartByte -> PlatformSerialC;
} 
