
 #include <stdio.h>
 #include "CXLink.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;

  uses interface Rf1aStatus;
  uses interface Rf1aPacket;
  uses interface Packet;

  uses interface StdControl as SerialControl;
  uses interface Timer<TMilli>;
} implementation {
  bool started = FALSE;
  bool dutyCycling = FALSE;

  uint32_t cycleLen = 100;
  uint32_t activeFrames = 10;
  uint32_t nextWakeup = 0;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  bool transmitAgain = FALSE;
  
  enum{
    PAYLOAD_LEN= 50,
  };
  typedef nx_struct test_payload {
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;

  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop + wakeup at startDone\r\n");
    printf("d : duty cycle sleep/wakeup\r\n");
    printf("c : check current frame\r\n");
    printf("i : make invalid sleep request\r\n");
    printf("f : + frame shift request\r\n");
    printf("F : - frame shift request\r\n");
    printf("t : transmit\r\n");
    printf("T : transmit x2\r\n");
    printf("p : pause serial (for 5 seconds)\r\n");
    printf("r : request long-duration receive\r\n");
    printf("k : kill serial (requires BSL reset/power cycle to resume)\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
//      //SMCLK to 1.1
//      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL &= ~BIT1;
      P1OUT &= ~BIT1;
//      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
    }
  }

  task void toggleStartStop(){
    if (started){
      printf(" Stop %x \r\n", call SplitControl.stop());
    }else{
      printf(" Start %x \r\n", call SplitControl.start());
    }
  }

  event void SplitControl.startDone(error_t error){
    printf("started %x status %x\r\n", error, call Rf1aStatus.get());
    started = TRUE;
    printf("wakeup req %x\r\n", 
      call CXRequestQueue.requestWakeup(
        call CXRequestQueue.nextFrame(), 0));
  }

  event void SplitControl.stopDone(error_t error){
    printf("stopped %x status %x\r\n", error, call Rf1aStatus.get());
    started = FALSE;
  }

  task void dutyCycle(){
    if (! dutyCycling){
      uint32_t fn = call CXRequestQueue.nextFrame() + 5;
      printf("wakeup req %x\r\n", call CXRequestQueue.requestWakeup(fn, 0));
      printf("sleep req %x\r\n", call CXRequestQueue.requestSleep(fn,
      activeFrames));
      dutyCycling = TRUE;
    }
  }

  task void shiftPositive(){
    printf("shift+ %x\r\n", 
      call CXRequestQueue.requestFrameShift(call
      CXRequestQueue.nextFrame(), 1, 256));
  }

  task void shiftNegative(){
    printf("shift- %x\r\n", 
      call CXRequestQueue.requestFrameShift(call
      CXRequestQueue.nextFrame(), 1, -256));
  }

  event void CXRequestQueue.frameShiftHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame){
    printf("shift handled: %x\r\n", error);
  }

  task void requestShortReceive(){
    call CXRequestQueue.requestReceive(
      dutyCycling ? nextWakeup: call CXRequestQueue.nextFrame(), 1, 
      FALSE, 0,
      RX_DEFAULT_WAIT,
      msg);
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, bool didReceive, 
      uint32_t microRef, message_t* msg_){
    printf("rx handled: %x @ %lu req %lu %x %lu\r\n",
      error, atFrame, reqFrame, didReceive, microRef);
    if (didReceive){
      post requestShortReceive();
    }
  }


  event void CXRequestQueue.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, uint32_t microRef, 
      message_t* msg_){
    if (error != SUCCESS){
      printf("send handled: %x\r\n", error);
    }
//    printf("send handled: %x %lu %lu %p %u\r\n", error, atFrame,
//      microRef, msg_, 
//      (call Rf1aPacket.metadata(msg))->payload_length);
    if (transmitAgain){
      test_payload_t* pl = (test_payload_t*)call Packet.getPayload(msg, sizeof(test_payload_t));
      error = call CXRequestQueue.requestSend(atFrame, 1, 
          TRUE, microRef, 
          &pl->timestamp, msg);
      if (SUCCESS != error){
        printf("resend %x\r\n", error);
      }
      transmitAgain = FALSE;
    }
  }

  event void CXRequestQueue.sleepHandled(error_t error,
      uint32_t atFrame, uint32_t reqFrame){
    if (error != SUCCESS){
      printf("sleep handled: %x @ %lu req %lu\r\n", error, atFrame,
        reqFrame);
    }else{
      if (dutyCycling){
        error = call CXRequestQueue.requestSleep(atFrame, cycleLen);
      }
    }
  }

  event void CXRequestQueue.wakeupHandled(error_t error,
      uint32_t atFrame, uint32_t reqFrame){
    if (error != SUCCESS){
      printf("wakeup handled: %x @ %lu req %lu\r\n", error, atFrame,
        reqFrame);
    }else{
      if (dutyCycling){
        error = call CXRequestQueue.requestWakeup(atFrame, cycleLen);
      }
    }
    nextWakeup = atFrame + cycleLen;
  }

  task void checkFrame(){
    printf("nf: %lu\r\n", call CXRequestQueue.nextFrame());
  }

  task void invalidSleep(){
    printf("invalid sleep: %x\r\n", 
      call CXRequestQueue.requestWakeup(call CXRequestQueue.nextFrame(), -1));
  }

  void doTransmit(){
    if (nextWakeup){
      test_payload_t * pl;
      call Rf1aPacket.configureAsData(msg);
      pl = (test_payload_t*)call Packet.getPayload(msg, sizeof(test_payload_t));
      if (pl != NULL){
        uint8_t i;
        for (i = 0; i < PAYLOAD_LEN; i++){
          pl->buffer[i] = i;
        }
        call Packet.setPayloadLength(msg, sizeof(test_payload_t));
  
        printf("tx: %x %p %p\r\n", call CXRequestQueue.requestSend(
        dutyCycling ? nextWakeup: call CXRequestQueue.nextFrame(), 1, 
          FALSE, 1, 
          NULL,
//          &(pl->timestamp),
          msg),
          pl,
          &(pl->timestamp));
      }else{
        printf("PL size error?\r\n");
      }
    }
  }

  task void transmit(){
    transmitAgain = FALSE;
    doTransmit();
  }

  task void transmitx2(){
    transmitAgain = TRUE;
    doTransmit();
  }

  uint16_t ctl6;
  uint16_t ctl8;

  task void pauseSerial(){
    printf("pausing serial\r\n");
    call SerialControl.stop();
    atomic{
      ctl6 = UCSCTL6;
      ctl8 = UCSCTL8;
    }
    printf("nothing, right?\r\n");
    call Timer.startOneShot(5120);
  }

  task void killSerial(){
    printf("killing serial\r\n");
    call SerialControl.stop();
  }

  event void Timer.fired(){
    call SerialControl.start();
    printf("resume serial\r\n");
  }

  task void requestLongReceive(){
    printf("rx req: %x\r\n", 
      call CXRequestQueue.requestReceive(
        dutyCycling ? nextWakeup: call CXRequestQueue.nextFrame(), 1, 
        FALSE, 0,
        RX_MAX_WAIT >> 5,
        msg));
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 'd':
         post dutyCycle();
         break;
       case 'c':
         post checkFrame();
         break;
       case 'i':
         post invalidSleep();
         break;
       case 'f':
         post shiftPositive();
         break;
       case 'F':
         post shiftNegative();
         break;
       case 't':
         post transmit();
         break;
       case 'T':
         post transmitx2();
         break;
       case 'p':
         post pauseSerial();
         break;
       case 'k':
         post killSerial();
         break;
       case 'r':
         post requestLongReceive();
         break;
       case '?':
         post usage();
         break;
       case '\r':
         printf("\n");
         break;
       default:
         break;
     }
     printf("%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
}
