#include "printf.h"
module MetadataP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface AMSend as TestSend;
  uses interface Packet;
  uses interface SplitControl as SerialSplitControl;
} implementation {
  message_t msg_internal;
  message_t* msg = &msg_internal;

  event void Boot.booted(){
    printf("Booted.\n");
    call SerialSplitControl.start();
  }

  event void SerialSplitControl.startDone(error_t error){
    call Timer.startPeriodic(1024);
  }

  event void SerialSplitControl.stopDone(error_t error){}

  task void testSend();
  event void Timer.fired(){
    printf("Fired.\n");
    printfflush();
    post testSend();
  }

  task void testSend(){
    test_msg_t* pl = (test_msg_t*) (call Packet.getPayload(msg,
      sizeof(test_msg_t)));
    pl -> counter ++;
    call TestSend.send(AM_BROADCAST_ADDR, msg, sizeof(test_msg_t));
  }

  event void TestSend.sendDone(message_t* msg_, error_t error){ }
}
