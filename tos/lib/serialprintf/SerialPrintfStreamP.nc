/*
 * Copyright (c) 2005-2006 Rincon Research Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Rincon Research Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * RINCON RESEARCH OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */
 
#include "serialprintf.h"

/** 
 * @author David Moss
 * @author Kevin Klues
 */
module SerialPrintfStreamP {
  uses {
    interface StdControl as UartControl;
    interface UartStream;
  }
  provides {
    interface StdControl;
    interface Init;
  }
}

implementation {
  
  command error_t Init.init () {
    return call StdControl.start();
  }

  command error_t StdControl.start ()
  {
    return call UartControl.start();
  }

  command error_t StdControl.stop ()
  {
    return call UartControl.stop();
  }

  uint8_t buf0[PRINTF_STREAM_BUF_LEN];
  uint8_t buf1[PRINTF_STREAM_BUF_LEN];

  uint8_t* fillBuf = buf0;
  uint8_t* swapBuf = buf1;
  uint8_t cnt = 0;
  bool sending;

  error_t sendAndSwap(){
    atomic{
      if (sending){
        //debug code
//        swapBuf[cnt-2]='!';
        return EBUSY;
      }else{
        uint8_t* newFillBuf = swapBuf;
        error_t error;
        swapBuf = fillBuf;
        fillBuf = newFillBuf;
        //debug code
//        swapBuf[0]='*';
        error = call UartStream.send(swapBuf, cnt);
        sending = (SUCCESS == error);
        cnt = 0;
        return error;
      }
    }
  }

  task void sendAndSwapTask(){
    sendAndSwap();
  }

  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) { 
    sending = FALSE;
    if (cnt){
      post sendAndSwapTask();
    }
  }


  /***************** Printf Implementation ****************/
#ifdef _H_msp430hardware_h
  int (putchar)(int c) __attribute__((noinline)) @C() @spontaneous()
#endif
#ifdef _H_atmega128hardware_H
  int uart_putchar(char c, FILE *stream) __attribute__((noinline)) @C() @spontaneous()
#endif
  {
    atomic{
      if (cnt == PRINTF_STREAM_BUF_LEN){
        //immediately start a send and get the free buffer. If we can't
        //make the swap, return an error.
        if (SUCCESS != sendAndSwap()){
          return -1;
        }
      }
      //if we reach this point, there is a buffer available and it has
      //  some space in it.
      fillBuf[cnt] = c;
      cnt++;
    }
    //Printf should be doing all of the putchar's in the
    //same execution context, so posting this as a task will
    //implicitly wait until the printf (or series of printf's) yield
    //and will then spit them out.
    post sendAndSwapTask();
    return c;
  }
  async event void UartStream.receivedByte(uint8_t c){}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len,
  error_t error){}
}

