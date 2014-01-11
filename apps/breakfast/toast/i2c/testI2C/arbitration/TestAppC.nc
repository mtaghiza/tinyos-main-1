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

configuration TestAppC{
} implementation {
  components MainC;
  components new TimerMilliC();

  components TestP;
  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;

  components new Msp430UsciI2CB0C() as I2CMaster;
  I2CMaster.Msp430UsciConfigure -> TestP.I2CConfigure;
  TestP.I2CResource -> I2CMaster.Resource;
  TestP.I2CPacket -> I2CMaster.I2CPacket;
  TestP.I2CSlave -> I2CMaster.I2CSlave;

  components PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartByte -> PlatformSerialC;
  TestP.StdControl -> PlatformSerialC;

  components new Msp430InterruptC();
  components HplMsp430InterruptC;
  Msp430InterruptC.HplInterrupt -> HplMsp430InterruptC.Port12;

  components new Msp430GpioC();
  components HplMsp430GeneralIOC;
  Msp430GpioC.HplGeneralIO -> HplMsp430GeneralIOC.Port12;

  TestP.OWIO -> Msp430GpioC;
  TestP.OWInterrupt -> Msp430InterruptC;
}
