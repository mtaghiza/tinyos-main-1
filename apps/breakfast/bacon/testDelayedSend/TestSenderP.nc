//#include "printf.h"

module TestSenderP {
  uses interface Boot;
  uses interface AMSend as RadioSend;
  uses interface SplitControl;
  uses interface Leds;
  uses interface DelayedSend;
  uses interface Timer<TMilli>;
} implementation {
  bool midSend = FALSE; 
  uint16_t seqNum;
  message_t rmsg;

  task void loadNextTask();
  event void Boot.booted(){
    printf("Booted\n\r");
    call SplitControl.start();
  }

  event void Timer.fired(){
    if (midSend){
      printf("Completing send\n\r");
      atomic{
        midSend  = FALSE;
        call DelayedSend.completeSend();
      }
    }else{
      post loadNextTask();
    }
  }

  event void SplitControl.startDone(error_t err){
    printf("Radio on\n\r");
    atomic{
      post loadNextTask();
    }
  }

  task void loadNextTask(){
    test_packet_t* pl = (test_packet_t*)call RadioSend.getPayload(&rmsg, sizeof(test_packet_t));
    pl -> seqNum = seqNum;
    printf("RS.send %x \n\r", call RadioSend.send(AM_BROADCAST_ADDR,
      &rmsg, sizeof(test_packet_t)));
  }

  task void reportSR(){
    printf("SR\n\r");
    call Timer.startOneShot(1024);
    midSend = TRUE;
  }

  async event void DelayedSend.sendReady(){
    post reportSR();
  }

  event void RadioSend.sendDone(message_t* msg, error_t err){
    printf("SEND DONE\n\r");
    call Timer.startOneShot(1024);
  }

  event void SplitControl.stopDone(error_t err){
  }

}
