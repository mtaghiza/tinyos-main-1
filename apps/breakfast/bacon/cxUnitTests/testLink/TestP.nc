
 #include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;
} implementation {
  bool started = FALSE;
  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop\r\n");
    printf("s : sleep\r\n");
    printf("w : wakeup\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
  }

  task void toggleStartStop(){
    if (started){
      printf(" Stop %x \r\n", call SplitControl.stop());
    }else{
      printf(" Start %x \r\n", call SplitControl.start());
    }
  }

  event void SplitControl.startDone(error_t error){
    printf("started %x\r\n", error);
    started = TRUE;
  }
  event void SplitControl.stopDone(error_t error){
    printf("stopped %x\r\n", error);
    started = FALSE;
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive, 
    uint32_t microRef, message_t* msg){}

  event void CXRequestQueue.sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg){}
  event void CXRequestQueue.sleepHandled(error_t error,
    uint32_t atFrame){}
  event void CXRequestQueue.wakeupHandled(error_t error,
    uint32_t atFrame){}

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
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
