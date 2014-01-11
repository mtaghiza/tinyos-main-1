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

configuration PlatformCC1190C{
  provides interface Init;
  provides interface CC1190;
  provides interface StdControl;
} implementation{
  #ifdef HAS_CC1190
  components CC1190P;
  #else
  components NoCC1190P as CC1190P;
  #endif

  components HplMsp430GeneralIOC;
  
  components new Msp430GpioC() as HGMGpio;
  HGMGpio.HplGeneralIO -> HplMsp430GeneralIOC.PortJ0;
  CC1190P.HGMPin -> HGMGpio;

  components new Msp430GpioC() as LNA_ENGpio;
  LNA_ENGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port35;
  CC1190P.LNA_ENPin -> LNA_ENGpio;

  components new Msp430GpioC() as PA_ENGpio;
  PA_ENGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port34;
  CC1190P.PA_ENPin -> PA_ENGpio;

  components new Msp430GpioC() as PowerGpio;
  PowerGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port36;
  CC1190P.PowerPin -> PowerGpio;
  
  Init = CC1190P;
  CC1190 = CC1190P;
  StdControl = CC1190P;

}
