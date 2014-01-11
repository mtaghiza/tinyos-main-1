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

module TestP{
  uses interface Boot;
} implementation {
  //argahga why do none of these do what I want??!
  //this seems like I should want
  // mode=up
  // output: set/reset
  // TA1CCR0: period (end of pulse)
  // TA1CCR1: start of pulse
  // and decreasing TA1CCR1 should give me a wider pulse.
  uint16_t period = 1 << 15;

  //outmod_3
  uint8_t outmod = OUTMOD_3;
  ////1<<15, 1024: 41.7 ns, 1.29 ms
  uint16_t pulseStart = 1 << 15;
  uint16_t pulseDuration = 1<<14;

  ////1<<15, 2048: 41,7 ns, 1.339 ms
  //uint16_t pulseStart = 1 << 15;
  //uint16_t pulseDuration = 2048;

  ////1<<15, 4096: 41,7 ns, 1.418 ms
  //uint16_t pulseStart = 1 << 15;
  //uint16_t pulseDuration = 4096;

  task void kickNext(){
    //TODO: set up for a single pulse, some time in the future, with
    //duration = pulseDuration
  }

  event void Boot.booted(){
    //uint8_t period_shift = 8;

    //select peripheral function for PM_TA1CCR0A (I think)
    P2SEL |= 3 << 1;
    P2DIR |= 3 << 1;
    //stop timer a 1
    TA1CTL = MC__STOP;

    //per note in datasheet "switching between output modes"
    TA1CCTL0 = OUTMOD_7;
    TA1CCTL0 = outmod;

    TA1CCR0 = period;
    TA1CCR2 = period - pulseDuration; 

    //start timer 1 
    TA1CTL = TASSEL_3 | ID_0 | MC__UP | TACLR;
  }

  //TODO: at overflow interrupt, stop the timer
}
