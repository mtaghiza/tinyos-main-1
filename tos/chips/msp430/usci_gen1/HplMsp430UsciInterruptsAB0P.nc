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
 * Define the interrupt handlers for USCI module A0 and B0.
 * First-gen USCI modules A0 and B0 share interrupt vectors, which is
 * delightful
 *
 * @author Peter A. Bigot <pab@peoplepowerco.com>
 * @author Marcus Chang
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

module HplMsp430UsciInterruptsAB0P {
  provides {
    interface HplMsp430UsciInterrupts as InterruptsUCA0Rx;
    interface HplMsp430UsciInterrupts as InterruptsUCA0Tx;
    interface HplMsp430UsciInterrupts as InterruptsUCA0State;
    interface HplMsp430UsciInterrupts as InterruptsUCB0Rx;
    interface HplMsp430UsciInterrupts as InterruptsUCB0Tx;
    interface HplMsp430UsciInterrupts as InterruptsUCB0State;
  }
} implementation {

  TOSH_SIGNAL(USCIAB0RX_VECTOR) 
  {
    //P6OUT ^= 0x40;
    //P6OUT ^= 0x40;
    //P6OUT = 0x06;
    //UCA0RXIFG -> A0Rx (IFG2)
    if ((IFG2 & UCA0RXIFG) && (IE2 & UCA0RXIE) )
    {
      signal InterruptsUCA0Rx.interrupted(IFG2);

    //UCB0RXIFG -> B0Rx (IFG2)
    } else if((IFG2 & UCB0RXIFG) && (IE2 & UCB0RXIE)){
      //P6OUT = 0x07;
      signal InterruptsUCB0Rx.interrupted(IFG2);

    //UCALIFG, UCNACKIFG, UCSTTIFG, UCSTPIFG 
    //  -> B0State(UCB0STAT)
    //TODO: should be 0x0f & UCB0I2CIE & UCB0STAT
    }else if(UCB0I2CIE & UCB0STAT ){
      //P6OUT = 0x08;
      signal InterruptsUCB0State.interrupted(UCB0STAT);  
    }else {
      //P6OUT = 0x09;
      //should not happen
    }
  }

  TOSH_SIGNAL(USCIAB0TX_VECTOR) 
  {
    //P6OUT ^= 0x80;
    //P6OUT ^= 0x80;
    //P6OUT = 0x0a;
    //UCA0TXIFG -> A0Tx (IFG2)
    if ( (IFG2 & UCA0TXIFG) && (IE2 & UCA0TXIE) )
    {
      signal InterruptsUCA0Tx.interrupted(IFG2);

    //UCB0RXIFG -> B0Rx (IFG2)
    } else if ( (IFG2 & UCB0RXIFG) && (IE2 & UCB0RXIE) ) {
      //P6OUT = 0x0b;
      signal InterruptsUCB0Rx.interrupted(IFG2);  

    //UCB0TXIFG -> B0Tx (IFG2)
    }else if ( (IFG2 & UCB0TXIFG) && (IE2 & UCB0TXIE) ) {
      //P6OUT = 0x0c;
      signal InterruptsUCB0Tx.interrupted(IFG2);  
    }else{
      //P6OUT = 0x0d;
      //should not happen
    }
  }

  default async event void InterruptsUCB0Rx.interrupted(uint8_t iv){}
  default async event void InterruptsUCB0Tx.interrupted(uint8_t iv){ }
  default async event void InterruptsUCB0State.interrupted(uint8_t iv){}
  default async event void InterruptsUCA0Rx.interrupted(uint8_t iv){}
  default async event void InterruptsUCA0Tx.interrupted(uint8_t iv){ }
  default async event void InterruptsUCA0State.interrupted(uint8_t iv){}

}
