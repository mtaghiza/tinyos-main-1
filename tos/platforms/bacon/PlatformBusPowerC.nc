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

configuration PlatformBusPowerC{
  provides interface Init;
} implementation {
  components PlatformBusPowerP;
  components BusPowerC;

  Init = PlatformBusPowerP;

  BusPowerC.SubSplitControl -> PlatformBusPowerP;
  components HplMsp430GeneralIOC;

  components new Msp430GpioC() as EnablePin;
  EnablePin.HplGeneralIO -> HplMsp430GeneralIOC.Port37;

  components new Msp430GpioC() as I2CData;
  I2CData.HplGeneralIO -> HplMsp430GeneralIOC.Port26;

  components new Msp430GpioC() as I2CClk;
  I2CClk.HplGeneralIO -> HplMsp430GeneralIOC.Port27;

  components new Msp430GpioC() as Term1WB;
  Term1WB.HplGeneralIO -> HplMsp430GeneralIOC.Port10;

  PlatformBusPowerP.EnablePin -> EnablePin;
  PlatformBusPowerP.I2CData -> I2CData;
  PlatformBusPowerP.I2CClk -> I2CClk;
  PlatformBusPowerP.Term1WB -> Term1WB;

  components new TimerMilliC();
  PlatformBusPowerP.Timer -> TimerMilliC;
}
