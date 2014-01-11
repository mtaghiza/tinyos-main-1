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

module TestP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface Leds;
} implementation {
  uint16_t counter;
  #define TIMER_OFFSET 64
  #define TIMER_PERIOD (uint32_t)128

  event void Boot.booted(){
    uint32_t timerNow = call Timer.getNow();
    P2SEL &= ~(BIT1|BIT4);
    P2OUT &= ~BIT4;
    P2OUT |= BIT1;
    P2DIR |= (BIT1|BIT4);

    atomic{
      PMAPPWD= 0x02D52;
      P1MAP1 = PM_ACLK;
      P1MAP2 = PM_MCLK;
      PMAPPWD = 0;
    }
    P1DIR |= BIT1|BIT2|BIT3|BIT4;
    P1SEL |= BIT1|BIT2;
    P1SEL &= ~(BIT3|BIT4);

    printf("now: %lu \n\r", timerNow);
    call Timer.startPeriodicAt(128, 64);
  }

  event void Timer.fired(){
    P2OUT = (P2OUT & ~BIT4) | ((READ_SR & SR_GIE)? BIT4 : 0x00);
    P1OUT |= BIT3;
    atomic{
//      P1OUT |= BIT4;
//      printf("F: %lu\r\n", call Timer.getNow());
//      P1OUT &= ~BIT4;
      uint16_t i;
      P2OUT = (P2OUT & ~BIT4) | ((READ_SR & SR_GIE)? BIT4 : 0x00);
      for(i = 0x00ff; i!=0 ; i--){
        nop();
      }
    }
    P1OUT &= ~BIT3;
    P2OUT = (P2OUT & ~BIT4) | ((READ_SR & SR_GIE)? BIT4 : 0x00);
    counter++;
    call Leds.set(counter);
  }
}
