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

/**
 * Define the interrupt handlers for USCI module A0.
 *
 * @author Peter A. Bigot <pab@peoplepowerco.com>
 */

module HplMsp430UsciInterruptsAB0P {
  provides {
    interface HplMsp430UsciInterrupts as InterruptsUCA0Rx;
    interface HplMsp430UsciInterrupts as InterruptsUCA0Tx;
    interface HplMsp430UsciInterrupts as InterruptsUCB0Rx;
    interface HplMsp430UsciInterrupts as InterruptsUCB0Tx;
    interface HplMsp430UsciInterrupts as InterruptsUCB0State;
  }
  uses {
//    interface HplMsp430Usci as Usci;
    interface Leds;
  }
} implementation {

  TOSH_SIGNAL(USCIAB0RX_VECTOR) 
  {
    /* UCA0RXIFG and UCA0RXIE set */
    if ((IFG2 & UCA0RXIFG) && (IE2 & UCA0RXIE) )
    {
      signal InterruptsUCA0Rx.interrupted(IFG2);

    /* UCB0 State change */
    } else {
      signal InterruptsUCB0State.interrupted(IFG2);  
    }
  }

  TOSH_SIGNAL(USCIAB0TX_VECTOR) 
  {        
    /* UCA0TXIFG and UCA0TXIE set */
    if ( (IFG2 & UCA0TXIFG) && (IE2 & UCA0TXIE) )
    {
      signal InterruptsUCA0Tx.interrupted(IFG2);
    }

    /* UCB0RXIFG and UCB0RXIE set */
    else if ( (IFG2 & UCB0RXIFG) && (IE2 & UCB0RXIE) )
    {
      signal InterruptsUCB0Rx.interrupted(IFG2);  
    }

    /* UCB0TXIFG and UCB0TXIE set */
    else if ( (IFG2 & UCB0TXIFG) && (IE2 & UCB0TXIE) )
    {
      signal InterruptsUCB0Tx.interrupted(IFG2);  
    }
  }

  default async event void InterruptsUCB0Rx.interrupted(uint8_t iv){}
  default async event void InterruptsUCB0Tx.interrupted(uint8_t iv){}
  default async event void InterruptsUCB0State.interrupted(uint8_t iv){}
  default async event void InterruptsUCA0Rx.interrupted(uint8_t iv){}
  default async event void InterruptsUCA0Tx.interrupted(uint8_t iv){}

}
