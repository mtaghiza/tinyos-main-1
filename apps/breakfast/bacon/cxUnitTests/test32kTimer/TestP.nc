
 #include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface Timer<T32khz>;
  
} implementation {
  event void Timer.fired(){
    atomic{
      P2OUT ^= BIT4;
    }
    printf("Fired %lu\r\n", call Timer.getNow());
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
    call Timer.startPeriodic(32768UL);
    atomic{
      P2SEL &= ~BIT4;
      P2DIR |= BIT4;
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
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
