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


 #include "AM.h"
  #include "fixedPointUtils.h"
module TestSkewP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface SkewCorrection;
} implementation {
  #define FPC 256UL
  uint32_t remoteRate = 1024UL * FPC;
  uint32_t localRate  = 1024UL * FPC;

  uint32_t localTime = 0;
  uint32_t remoteTime = 0;
  uint32_t fn = 0;
  
  task void usage(){
    printf("== Skew correction test ==\r\n");
    printf("--------------------------\r\n");
    printf(" q : reset\r\n");
    printf(" l : increase local speed by 1 tick per cycle\r\n");
    printf(" L : decrease local speed by 1 tick per cycle\r\n");
    printf(" r : increase remote speed by 1 tick per cycle\r\n");
    printf(" R : decrease remote speed by 1 tick per cycle\r\n");
    printf(" ? : print current settings + this message\r\n");
    printf(" m : add measurement\r\n");
    printf("..........................\r\n");
    printf(" Local rate: %lu Remote rate: %lu\r\n", 
      localRate, remoteRate);
  }

  event void Boot.booted(){
    call SerialControl.start();
    printf("booted\r\n");
    post usage();
  }

  task void increaseLocal(){
    localRate ++;
  }

  task void decreaseLocal(){
    localRate --;
  }

  task void increaseRemote(){
    remoteRate ++;
  }

  task void decreaseRemote(){
    remoteRate --;
  }

  task void nextMeasurement(){
    printf("add next measurement\r\n");
    localTime += localRate;
    remoteTime += remoteRate;
    fn += FPC;
    call SkewCorrection.addMeasurement(0xDC,
      TRUE, remoteTime, fn, localTime);
  }

  task void test64Bit(){
    int64_t longAssInt = 0xcafebabe;
    printf("%llx\r\n", longAssInt);
  }

  task void test32Bit(){
    int32_t longAssInt = 0xbabe;
    printf("%lx\r\n", longAssInt);
  }

  task void testFpMult(){
    fpMult(toFP(-1, 16), toFP(-1,16), 16);
    printf("%li\r\n", 0xffff0000);
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 'l':
        post increaseLocal();
        break;
      case 'L':
        post decreaseLocal();
        break;
      case 'r':
        post increaseRemote();
        break;
      case 'R':
        post decreaseRemote();
        break;
      case 'm':
        post nextMeasurement();
        break;
      case '?':
        post usage();
        break;
      case 't':
        post test64Bit();
//        post test32Bit();
        break;
      case '\r':
        printf("\n");
        break;
      case '!':
        post testFpMult();
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
