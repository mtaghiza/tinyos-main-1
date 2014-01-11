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
