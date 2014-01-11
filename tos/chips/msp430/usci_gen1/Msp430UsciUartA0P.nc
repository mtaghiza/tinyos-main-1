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

configuration Msp430UsciUartA0P {
  provides {
    interface UartStream[uint8_t client];
    interface UartByte[uint8_t client];
    interface ResourceConfigure[uint8_t client];
    interface Msp430UsciError[uint8_t client];
  }
  uses {
    interface Msp430UsciConfigure[ uint8_t client ];
    interface HplMsp430GeneralIO as URXD;
    interface HplMsp430GeneralIO as UTXD;
  }
} implementation {

  components Msp430UsciA0P as UsciC;
  //masks are module-specific so they need to be passed in.
  //alternately, the masks could be retrieved from the UsciA interface
  components new Msp430UsciUartP(UCA0TXIE, UCA0RXIE, UCA0TXIFG, UCA0RXIFG) as UartC;

  UartC.Usci -> UsciC;
  UartC.UsciA -> UsciC;
  UartC.RXInterrupts -> UsciC.RXInterrupts[MSP430_USCI_UART];
  UartC.TXInterrupts -> UsciC.TXInterrupts[MSP430_USCI_UART];
  UartC.StateInterrupts -> UsciC.StateInterrupts[MSP430_USCI_UART];
  UartC.ArbiterInfo -> UsciC;

  Msp430UsciConfigure = UartC;
  ResourceConfigure = UartC;
  UartStream = UartC;
  UartByte = UartC;
  Msp430UsciError = UartC;
  URXD = UartC.URXD;
  UTXD = UartC.UTXD;

  components LocalTimeMilliC;
  UartC.LocalTime_bms -> LocalTimeMilliC;

}
