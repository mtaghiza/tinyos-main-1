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

//#include "printf.h"

module TestSenderP {
  uses interface Boot;
  uses interface AMSend as RadioSend;
  uses interface SplitControl;
  uses interface Leds;
  uses interface DelayedSend;
  uses interface Timer<TMilli>;
} implementation {
  bool midSend = FALSE; 
  uint16_t seqNum;
  message_t rmsg;

  task void loadNextTask();
  event void Boot.booted(){
    printf("Booted\n\r");
    call SplitControl.start();
  }

  event void Timer.fired(){
    if (midSend){
      printf("Completing send\n\r");
      atomic{
        midSend  = FALSE;
        call DelayedSend.completeSend();
      }
    }else{
      post loadNextTask();
    }
  }

  event void SplitControl.startDone(error_t err){
    printf("Radio on\n\r");
    atomic{
      post loadNextTask();
    }
  }

  task void loadNextTask(){
    test_packet_t* pl = (test_packet_t*)call RadioSend.getPayload(&rmsg, sizeof(test_packet_t));
    pl -> seqNum = seqNum;
    printf("RS.send %x \n\r", call RadioSend.send(AM_BROADCAST_ADDR,
      &rmsg, sizeof(test_packet_t)));
  }

  task void reportSR(){
    printf("SR\n\r");
    call Timer.startOneShot(1024);
    midSend = TRUE;
  }

  async event void DelayedSend.sendReady(){
    post reportSR();
  }

  event void RadioSend.sendDone(message_t* msg, error_t err){
    printf("SEND DONE\n\r");
    call Timer.startOneShot(1024);
  }

  event void SplitControl.stopDone(error_t err){
  }

}
