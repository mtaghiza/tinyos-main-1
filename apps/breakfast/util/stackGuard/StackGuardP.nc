
 #include "StackGuard.h"
module StackGuardP{
  uses interface Alarm<T32khz, uint16_t>;
  uses interface Leds;
  provides interface Init;
} implementation {

  command error_t Init.init(){
    END_OF_STACK[1] = 0xde;
    END_OF_STACK[2] = 0xad;
    END_OF_STACK[3] = 0xbe;
    END_OF_STACK[4] = 0xef;
    call Alarm.start(STACKGUARD_CHECK_INTERVAL);
    return SUCCESS;
  }

  async event void Alarm.fired(){
    if (END_OF_STACK[1] == 0xde && 
        END_OF_STACK[2] == 0xad &&
        END_OF_STACK[3] == 0xbe &&
        END_OF_STACK[4] == 0xef){
//      printf(".");
      call Alarm.startAt(call Alarm.getAlarm(), STACKGUARD_CHECK_INTERVAL);
    }else{
      //mspgcc apparently lets you mark some RAM as outside of the
      //.bss and .data sections (using RESERVE_RAM(x) in the def. of
      //main). It would be nice to be able to set this here.
      //also: how much of a killer would it be if we added the option
      //of tracing function calls (each function has a unique number,
      //they push it to the stack at each call?) so that we could not
      //only identify when a stack overflow occurred, but also trace
      //it back and see what triggered it?
      printf("STACK OVERFLOW %p\r\n", END_OF_STACK);
      //if there is a platform-independent software reset, that
      //would be nice to use here.
      WDTCTL = 0x00;
    }
  }


}
