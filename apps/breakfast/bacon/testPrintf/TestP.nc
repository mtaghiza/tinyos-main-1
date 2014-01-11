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


#if RAW_PRINTF == 1 
#include <stdio.h>
#else
#include "printf.h"
#endif

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
//    uint32_t timerAt = timerNow - TIMER_OFFSET;
    printf("now: %lu \r\n", timerNow);
    call Timer.startPeriodicAt(128, 1024);
  }
  task void printTask(){
    uint8_t i;
    uint8_t j;
    for (j = 0; j < 0x10; j++){
      for (i = 0; i < 0x10; i++){
        printf("%x%x%x%x%x%x%x%x\r\n", j, j, i, i, i, i, i, i);
      }
    }
  }

  event void Timer.fired(){
    printf("%lu\r\n", call Timer.getNow());
    post printTask();
    #if RAW_PRINTF == 0
    printfflush();
    #endif
    counter++;
    //printf("Test: %d\r\n", counter++);
    call Leds.set(counter);
  }
}
