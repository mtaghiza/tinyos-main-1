/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


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
