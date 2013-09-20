
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
