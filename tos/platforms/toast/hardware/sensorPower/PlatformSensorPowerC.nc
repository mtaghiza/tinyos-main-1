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

configuration PlatformSensorPowerC{
  provides interface GeneralIO as SensorPower[uint8_t channelNum];
} implementation {
  components HplMsp430GeneralIOC;

  components new Msp430GpioC() as Sensor0,
    new Msp430GpioC() as Sensor1,
    new Msp430GpioC() as Sensor2,
    new Msp430GpioC() as Sensor3,
    new Msp430GpioC() as Sensor4,
    new Msp430GpioC() as Sensor5,
    new Msp430GpioC() as Sensor6,
    new Msp430GpioC() as Sensor7;
  Sensor0.HplGeneralIO -> HplMsp430GeneralIOC.Port43;
  Sensor1.HplGeneralIO -> HplMsp430GeneralIOC.Port44;
  Sensor2.HplGeneralIO -> HplMsp430GeneralIOC.Port45;
  Sensor3.HplGeneralIO -> HplMsp430GeneralIOC.Port46;
  Sensor4.HplGeneralIO -> HplMsp430GeneralIOC.Port50;
  Sensor5.HplGeneralIO -> HplMsp430GeneralIOC.Port51;
  Sensor6.HplGeneralIO -> HplMsp430GeneralIOC.Port52;
  Sensor7.HplGeneralIO -> HplMsp430GeneralIOC.Port53;

  SensorPower[0] = Sensor0;
  SensorPower[1] = Sensor1;
  SensorPower[2] = Sensor2;
  SensorPower[3] = Sensor3;
  SensorPower[4] = Sensor4;
  SensorPower[5] = Sensor5;
  SensorPower[6] = Sensor6;
  SensorPower[7] = Sensor7;
}
