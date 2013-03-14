
 #include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;

  uses interface Rf1aStatus;
  uses interface Rf1aPacket;
} implementation {
  bool started = FALSE;
  bool dutyCycling = FALSE;

  uint32_t cycleLen = 100;
  uint32_t activeFrames = 10;
  uint32_t nextWakeup = 0;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop\r\n");
    printf("s : sleep/wakeup\r\n");
    printf("c : check current frame\r\n");
    printf("i : make invalid sleep request\r\n");
    printf("f : + frame shift request\r\n");
    printf("F : - frame shift request\r\n");
    printf("t : transmit\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //SMCLK to 1.1
      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL |= BIT1;
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
  }
  event void SplitControl.stopDone(error_t error){
    printf("stopped %x status %x\r\n", error, call Rf1aStatus.get());
    started = FALSE;
  }

  task void sleepWake(){
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
      uint32_t atFrame){
    printf("shift handled: %x\r\n", error);
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive, 
    uint32_t microRef, message_t* msg_){}

  event void CXRequestQueue.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t microRef, 
      message_t* msg_){
    printf("send handled: %x %lu %lu %p\r\n", error, atFrame,
      microRef, msg_);
  }

  event void CXRequestQueue.sleepHandled(error_t error,
      uint32_t atFrame){
//    printf("sleep handled %x status %x\r\n", error, 
//      call Rf1aStatus.get());
    if (dutyCycling){
      error = call CXRequestQueue.requestSleep(atFrame, cycleLen);
//      printf("sleep req %x \r\n", error); 
    }
  }

  event void CXRequestQueue.wakeupHandled(error_t error,
    uint32_t atFrame){
//    printf("wakeup handled %x status %x\r\n", error, 
//      call Rf1aStatus.get());
    if (dutyCycling){
      error = call CXRequestQueue.requestWakeup(atFrame, cycleLen);
//      printf("wake req %x \r\n", error);
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

  task void transmit(){
    if (nextWakeup){
      call Rf1aPacket.configureAsData(msg);
      (call Rf1aPacket.metadata(msg))->payload_length = 20;
      printf("tx: %x\r\n", call CXRequestQueue.requestSend(
        nextWakeup, 1,
        FALSE, 0, msg));
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 's':
         post sleepWake();
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
