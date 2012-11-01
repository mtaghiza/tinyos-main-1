#include "printf.h"
module MetadataP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface Packet;
  uses interface SplitControl as SerialSplitControl;
} implementation {
  message_t msg_internal;
  message_t* msg = &msg_internal;

  event void Boot.booted(){
    printf("Booted.\n");
    printfflush();
    call SerialSplitControl.start();
  }

  event void SerialSplitControl.startDone(error_t error){ }

  event void SerialSplitControl.stopDone(error_t error){}


  event void Timer.fired(){ }

}
