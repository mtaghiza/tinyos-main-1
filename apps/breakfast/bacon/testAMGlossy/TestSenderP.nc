#include "testAMGlossy.h"
#include <stdio.h>

module TestSenderP {
  uses interface Boot;
  uses interface AMSend as RadioSend; 
  uses interface Receive;
  uses interface SplitControl;
  uses interface Leds;
  uses interface Timer<TMilli>;
} implementation {
  bool midSend = FALSE; 
  uint16_t seqNum;
  message_t rmsg;

  task void startFlood();

  event void Boot.booted(){
    printf("Booted\n\r");
    call SplitControl.start();
  }

  event void Timer.fired(){
    #ifdef IS_ORIGINATOR
    post startFlood();
    #endif
  }

  event void SplitControl.startDone(error_t err){
    printf("Radio on\n\r");
    call Timer.startOneShot(FLOOD_INTERVAL);
  }

  task void startFlood(){
    test_packet_t* pl = (test_packet_t*)call RadioSend.getPayload(&rmsg, sizeof(test_packet_t));
    pl -> seqNum = seqNum;
    printf("RS.send %x \n\r", call RadioSend.send(AM_BROADCAST_ADDR,
      &rmsg, sizeof(test_packet_t)));
  }

  event void RadioSend.sendDone(message_t* msg, error_t err){
    printf("SEND DONE\n\r");
    call Timer.startOneShot(FLOOD_INTERVAL);
  }

  event message_t* Receive.receive(message_t* msg, void* payload,
      uint8_t len){
    test_packet_t* pl = (test_packet_t*)payload; 
    printf("Receive sn: %lu\n\r", pl->seqNum);
    return msg;
  }
 
  //unused events
  event void SplitControl.stopDone(error_t err){
  }

}
