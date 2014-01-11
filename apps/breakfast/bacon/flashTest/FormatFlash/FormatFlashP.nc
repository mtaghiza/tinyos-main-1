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

#include <stdio.h>
#include "decodeError.h"
module FormatFlashP
{
  uses {
    interface Boot;
    interface LogWrite;
    //interface LogRead;
    interface Leds;
    interface StdControl as UartCtl;
    interface UartStream;
    interface Timer<TMilli>;
  }
}

implementation
{
  task void formatTask();

  event void Timer.fired(){
    post formatTask();
  }

  event void Boot.booted()
  {
    printf("Format Flash Test\n\r");
    call UartCtl.start();
    if (AUTOMATIC){
      call Timer.startOneShot(1024);
    }else{
      printf("USAGE\r\n");
      printf("=====\r\n");
      printf("q: reset\r\n");
      printf("f: format\r\n");
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 'f':
        post formatTask();
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        printf("%c", byte);
    }
  }

  task void formatTask(){
    error_t err = call LogWrite.erase();
    printf("Erase: %x %s\n\r", err, decodeError(err));
    if (err == SUCCESS){
      call Leds.set(2);   // _G_
    } else {
      call Leds.set(7);   // BGR
    }
  }
  event void LogWrite.eraseDone(error_t err)
  {
    printf("EraseDone: %x %s\n\r", err, decodeError(err));
    if (err == SUCCESS) {
      call Leds.set(4);   // B__
    } else {
      call Leds.set(7);   // BGR
    }
  }
  
  //event void LogRead.readDone(void* buf, storage_len_t len, error_t error) {}
  //event void LogRead.seekDone(error_t error) {}
  
  event void LogWrite.syncDone(error_t error) {}
  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error) {}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
}
