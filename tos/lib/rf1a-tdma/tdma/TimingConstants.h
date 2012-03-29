#ifndef TIMING_CONSTANTS_H
#define TIMING_CONSTANTS_H

 #ifndef NUM_SRS
 #define NUM_SRS 10
 #endif

 const uint8_t symbolRates[NUM_SRS] = {
    1,
    2,
    5,
    10,
    39,
    77,
    100,
    125,
    175,
    250
  };

  const uint32_t frameLens[NUM_SRS] = {
    (DEFAULT_TDMA_FRAME_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/2UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/10UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/39UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/77UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/250UL, 
  };

  const uint32_t fwCheckLens[NUM_SRS] = {
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/2UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/10UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/39UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/77UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/250UL, 
  };
  
  //These are the delays (in 6.5 MHz ticks) between the SFD
  //as observed at the transmitter and the SFD at the receiver
  //these come from the logic analyzer (forwarder)
  const uint32_t sfdDelays[NUM_SRS] = {
    //1.2 
    0,
    //2.4
    0,
    //4.8
    0,
    //10
    0,
    //39  not yet running stable
    0,
    //77  0.0000320872092997829 208.566
    208,
    //100 0.0000237307692320645 154.25
    154,
    //125 9.3014354063222e-06 60.45
    61,
    //175 1.62371794875365e-05 105.541666669  odd
    106,
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
    //2.4
    0,
    //4.8
    0,
    //10
    0,
    //39  10939   0.00168292307692308
    10939,
    //77  5514.5  0.000848386138613861
    5515,
    //100 4255    0.000654627915071354
    4255,
    //125 3424    0.000526769230769231
    3426,
    //175 2482    0.000381797237110289
    2482,
    //250 1781    0.000274057315233786
    1781,
  };
  const int32_t tuningDelays[NUM_SRS] = {
    //1.2
    0,
    //2.4
    0,
    //4.8
    0,
    //10
    0,
    //39  
    0,
    //77  
    19,
    //100 
    11,
    //125 
    5,
    //175 This one seems less stable for some reason.
    -19,
    //250 also seems less stable.
    -8,
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
