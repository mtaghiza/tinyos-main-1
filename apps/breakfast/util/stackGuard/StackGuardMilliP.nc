
 #include "StackGuard.h"
module StackGuardMilliP{
  uses interface Timer<TMilli>;
  uses interface Leds;
  provides interface Init;
  uses interface UartStream;
} implementation {

  command error_t Init.init(){
    END_OF_STACK[1] = 0xde;
    END_OF_STACK[2] = 0xad;
    END_OF_STACK[3] = 0xbe;
    END_OF_STACK[4] = 0xef;
    call Timer.startPeriodic(STACKGUARD_CHECK_INTERVAL_MILLI);
    return SUCCESS;
  }
  
  const char* SO_MESSAGE="SO\r\n";

  event void Timer.fired(){
    if (END_OF_STACK[1] == 0xde && 
        END_OF_STACK[2] == 0xad &&
        END_OF_STACK[3] == 0xbe &&
        END_OF_STACK[4] == 0xef){
//      printf(".");
    }else{
      //mspgcc apparently lets you mark some RAM as outside of the
      //.bss and .data sections (using RESERVE_RAM(x) in the def. of
      //main). It would be nice to be able to set this here.
      //also: how much of a killer would it be if we added the option
      //of tracing function calls (each function has a unique number,
      //they push it to the stack at each call?) so that we could not
      //only identify when a stack overflow occurred, but also trace
      //it back and see what triggered it?
      if (call UartStream.send((uint8_t*)SO_MESSAGE, 4) == SUCCESS){
        //cool, wait until send finishes to log this.
      }else{
        //if there is a platform-independent software reset, that
        //would be nice to use here.
        atomic{
          WDTCTL = 0x00;
        }
      }
    }
  }

  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error){
    WDTCTL = 0x00;
  }
  async event void UartStream.receivedByte( uint8_t byte )  { }
  async event void UartStream.receiveDone( uint8_t* buf, 
    uint16_t len, error_t error ) {}

  default async command error_t UartStream.enableReceiveInterrupt(){
    return FAIL;
  }
  
  default async command error_t UartStream.send( uint8_t* buf, uint16_t len ){
    return FAIL;
  }
  default async command error_t UartStream.disableReceiveInterrupt(){
    return FAIL;
  }
  default async command error_t UartStream.receive( uint8_t* buf, uint16_t len ){
    return FAIL;
  }

}

