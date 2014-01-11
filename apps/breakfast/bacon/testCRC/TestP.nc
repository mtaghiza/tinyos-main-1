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

module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface UartStream;
  uses interface StdControl as UartControl;
  uses interface Crc;
  uses interface Timer<TMilli>;
} implementation {
  bool keepSampling = FALSE;
  const char* test_string = "Hello Checksum.";

  event void Timer.fired(){}

  event void Boot.booted(){
    call UartControl.start();
    printf("CHECKSUM tester\r\n");
    printf(" c: compute \r\n");
    printf("---------------\r\n");
  }

  task void compute(){
    printf("result: %x\r\n", call Crc.crc16((void*)test_string, 8));
  }

  async event void UartStream.receivedByte(uint8_t b){
    switch(b){
      case 'q':
        WDTCTL = 0;
        break;
      case 'c':
        post compute();
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        printf("%c", b);
    }
  }

  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}
}
