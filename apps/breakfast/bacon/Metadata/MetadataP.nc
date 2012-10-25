#include "printf.h"
module MetadataP{
  uses interface Boot;
  uses interface Timer<TMilli>;
} implementation {
  event void Boot.booted(){
    printf("Booted.\n");
    call Timer.startPeriodic(1024);
  }

  event void Timer.fired(){
    printf("Fired.\n");
  }
}
