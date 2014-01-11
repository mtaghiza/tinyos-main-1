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

#ifndef TIMING_CONSTANTS_H
#define TIMING_CONSTANTS_H

 #ifndef NUM_SRS
 #define NUM_SRS 7
 #endif

 const uint8_t symbolRates[NUM_SRS] = {
    1,
    5,
    50,
    100,
    125,
    175,
    250
  };

  const uint32_t frameLens[NUM_SRS] = {
    (DEFAULT_TDMA_FRAME_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/50UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/125UL, 
  };

  const uint32_t fwCheckLens[NUM_SRS] = {
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/50UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/125UL, 
  };
  
  //These are the delays (in 6.5 MHz ticks) between the SFD
  //as observed at the transmitter and the SFD at the receiver
  //these come from the logic analyzer (forwarder)
  const uint32_t sfdDelays[NUM_SRS] = {
    //1.2 
    0,
    //4.8
    0,
    //50 3.07692307695692e-05  200.000000002
    200,
    //100 2.37142857149429e-05,154.142857147
    154,
    //125 9.3014354063222e-06 60.45
    61,
    //175 1.62371794875365e-05 105.541666669  odd
    0,
    //250 1.36229016783686e-05 88.5488609094
    89,
  };
  
  //  the interrupt handling time appears to be very
  //  short/deterministic based on the LA timings.
  //  These figures are the delta from the scheduled alarm to the
  //  transmitter observing the SFD go out.
  // these come from the log output of the root node.
  // These are roughly inversely proportional to the symbol rate, but
  // there is some fixed delay built in at the frame start (prior to
  // the STX strobe being sent)
  const uint32_t fsDelays[NUM_SRS] = {
    //1.2
    0,
    //4.8
    0,
    //50  0.00129255769231077 8401.62500002
    8402,
    //100 0.0006497749999986 4223.53749999
    // on retest, this was off (fast) by 1.15476190421314e-06 7.50595237739
    // on retest again, this was off (fast) by another 1.18478260956491e-06 7.70108696217 
    // i'm leaving it for now, this is weird. should be close enough
    // to not lose synch too badly. 
    4216,
    //125 3424    0.000526769230769231
    3400,
    //175 2482    0.000381797237110289
    0,
    //250 1781    0.000274057315233786
    1723,
  };

  const int32_t originDelays[NUM_SRS] = {
    //1.2
    0,
    //4.8
    0,
    //50  
    0,
    //100 
    0,
    //125 
    0,
    //175 This one seems less stable for some reason.
    0,
    //250 also seems less stable.
    0,
  };

  //argh i don't see a way around doing this.
  uint8_t srIndex(uint8_t symbolRate){
    uint8_t i;
    for (i = 0; i < NUM_SRS; i++){
      if (symbolRates[i] == symbolRate){
        return i;
      }
    }
    printf("Unknown sr: %u\r\n", symbolRate);
    return 0xff;
  }


#endif
