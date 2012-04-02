generic module StateTimingP(uint8_t numStates, uint8_t initialState){
  provides interface StateTiming;
  uses interface SWCapture;
} implementation {
  uint32_t stateTimes[numStates];
  uint32_t overflows[numStates];
  uint8_t lastState = initialState;

  uint8_t qp = 0;
  uint32_t elapsedQueue[10];

  async command void StateTiming.start(uint8_t state){
    uint32_t elapsed = call SWCapture.capture();
    uint32_t last; 
    STATE_TIMING_CAP_SET_PIN;
    last = stateTimes[lastState];
    stateTimes[lastState] += elapsed;
    if (stateTimes[lastState] < last){
      printf_SW_CAPTURE("Overflow %x: %lu + %lu < %lu \r\n",
        state, last, elapsed, stateTimes[lastState]);
      overflows[lastState]++;
    }
//    printf("cap %x\r\n", state);

    STATE_TIMING_CAP_CLEAR_PIN;
//    if (lastState == 0x00){
//      elapsedQueue[(qp++)%10] = elapsed;
//    }
    lastState = state;
  }

  async command uint32_t StateTiming.getTotal(uint8_t state){
//    printf("gt %x\r\n", state);
//    if (state == 0x00){
//      uint8_t i;
//      printf("[");
//      for (i = 0; i < ((qp > 10)?10:qp); i++){
//        printf("%lu, ", elapsedQueue[i]);
//      }
//      printf("]\r\n");
//      qp = 0;
//    }
    return stateTimes[state];
  }

  async command uint32_t StateTiming.getOverflows(uint8_t state){
    return overflows[state];
  }
}
