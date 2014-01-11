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
module TestP{
  uses interface Boot;
  uses interface UartStream;

  provides interface Compare<cx_request_t*>;

  uses interface Pool<cx_request_t>;
  uses interface Queue<cx_request_t*>;
} implementation {

  event void Boot.booted(){
    printf("booted\r\n");
  }

  command bool Compare.leq(cx_request_t* l, cx_request_t* r){
    return requestLeq(l, r);
  }
  
  void enqueue(request_type_t requestType){
    cx_request_t* r = call Pool.get();
    if (r != NULL){
      r->requestType = requestType;
      call Queue.enqueue(r);
    }
  }

  task void enqueueSleep(){
    printf("Enqueue sleep\r\n");
    enqueue(RT_SLEEP);
  }

  task void enqueueRX(){
    printf("Enqueue RX\r\n");
    enqueue(RT_RX);
  }

  void printRequest(cx_request_t* r){
    printf("r: %p", r);
    printf(" t %x bf %lu fo %li rt %lu duration %lu useM %x tsm %lu msg %p\r\n",
      r->requestType,
      r->baseFrame,
      r->frameOffset,
      r->requestedTime,
      r->duration,
      r->useTsMicro,
      r->tsMicro,
      r->msg);
  }

  task void dequeueTask(){
    if (! call Queue.empty()){
      cx_request_t* h = call Queue.dequeue();
      printRequest(h);
      call Pool.put(h);
    } else {
      printf("empty\r\n");
    }
  }

  task void compareTask(){
    cx_request_t l;
    cx_request_t r;
    l.requestType = RT_SLEEP;
    r.requestType = RT_SLEEP;
    l.requestedTime = 1500;
    r.requestedTime = 1500;

    l.baseFrame = 5;
    r.baseFrame = 5;
    l.frameOffset = 2;
    r.frameOffset = 2;
    
    //test valid: should be equal
    printf("val l <= r:%x\r\n",
      requestLeq(&l, &r));
    printf("val r <= l:%x\r\n",
      requestLeq(&r, &l));
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 's':
        post enqueueSleep();
        break;
      case 'r':
        post enqueueRX();
        break;
      case 'd':
        post dequeueTask();
        break;
      case 'c':
        post compareTask();
        break;
      case '\r':
        printf("\n");
      default:
        printf("%c", byte);
    }
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
}
