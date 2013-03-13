
 #include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;
  uses interface Rf1aStatus;
} implementation {
  bool started = FALSE;
  bool dutyCycling = FALSE;

  uint32_t cycleLen = 100;
  uint32_t activeFrames = 10;

  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop\r\n");
    printf("s : sleep/wakeup\r\n");
    printf("c : check current frame\r\n");
    printf("i : make invalid sleep request\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
    post usage();
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
      uint32_t fn = call CXRequestQueue.nextFrame();
      printf("wakeup req %x\r\n", call CXRequestQueue.requestWakeup(fn, 0));
      printf("sleep req %x\r\n", call CXRequestQueue.requestSleep(fn,
      activeFrames));
      dutyCycling = TRUE;
    }
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive, 
    uint32_t microRef, message_t* msg){}

  event void CXRequestQueue.sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg){}

  event void CXRequestQueue.sleepHandled(error_t error,
      uint32_t atFrame){
    printf("sleep handled %x status %x\r\n", error, 
      call Rf1aStatus.get());
    if (dutyCycling){
      printf("sleep req %x \r\n", 
        call CXRequestQueue.requestSleep(atFrame, cycleLen));
    }
  }

  event void CXRequestQueue.wakeupHandled(error_t error,
    uint32_t atFrame){
    printf("wakeup handled %x status %x\r\n", error, 
      call Rf1aStatus.get());
    if (dutyCycling){
      printf("wake req %x \r\n", 
        call CXRequestQueue.requestWakeup(atFrame, cycleLen));
    }
  }

  task void checkFrame(){
    printf("nf: %lu\r\n", call CXRequestQueue.nextFrame());
  }

  task void invalidSleep(){
    printf("invalid sleep: %x\r\n", 
      call CXRequestQueue.requestWakeup(call CXRequestQueue.nextFrame(), -1));
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
