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

#include "testAMGlossy.h"
#include <stdio.h>

module TestSenderP {
  uses interface Boot;
  uses interface AMSend as RadioSend; 
  uses interface Receive;
  uses interface SplitControl;
  uses interface Leds;
  uses interface Timer<TMilli>;

  uses interface Rf1aPhysical;
  uses interface HplMsp430Rf1aIf;

  uses interface StdControl as SerialControl;
  uses interface UartStream;

  uses interface Rf1aDumpConfig;
  uses interface Rf1aConfigure;

} implementation {
  bool midSend = FALSE; 
  uint16_t seqNum;
  message_t rmsg;

  bool isOriginator = IS_ORIGINATOR;

  task void startFlood();

  event void Boot.booted(){
    printf("Test AM Glossy\n\r");
    P1SEL &= ~(BIT1|BIT2|BIT3|BIT4);
    P1DIR |= (BIT1|BIT2|BIT3|BIT4);
    P2SEL &= ~(BIT4);
    P2DIR |= (BIT4);
    call Rf1aDumpConfig.display(call Rf1aConfigure.getConfiguration());
    call SplitControl.start();
  }

  event void Timer.fired(){
    if (isOriginator){
      post startFlood();
    }
  }

  event void SplitControl.startDone(error_t err){
    printf("Radio on\n\r");
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call HplMsp430Rf1aIf.writeSinglePATable(POWER_SETTINGS[TEST_POWER_INDEX]);
    if (isOriginator){
      call Timer.startOneShot(FLOOD_INTERVAL);
    }
  }

  task void startFlood(){
    error_t error;
    test_packet_t* pl = (test_packet_t*)call RadioSend.getPayload(&rmsg, sizeof(test_packet_t));
    pl -> seqNum = seqNum;
    seqNum += 2;
    error = call RadioSend.send(AM_BROADCAST_ADDR, &rmsg,
      sizeof(test_packet_t));
    if (error != SUCCESS){
      printf("RS.send error: %x \n\r", error);
    }
  }

  event void RadioSend.sendDone(message_t* msg, error_t err){
    printf("SEND DONE\n\r");
    if (isOriginator){
      call Timer.startOneShot(FLOOD_INTERVAL);
    }
  }

  uint32_t lastSN;
  task void reportReceive(){
    printf("Receive sn: %lu\n\r", lastSN);
  }

  event message_t* Receive.receive(message_t* msg, void* payload,
      uint8_t len){
    test_packet_t* pl = (test_packet_t*)payload; 
    lastSN = pl->seqNum;
    post reportReceive();
    return msg;
  }
 
  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case '\r':
        printf("\n\r");
        break;
      case 't':
        isOriginator = !isOriginator;
        if (isOriginator){
          post startFlood();
        }
        printf("isOriginator: %x\n\r", isOriginator);
        break;
      default:
        printf("%c", byte);
        break;
    }
  }

  //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

  event void SplitControl.stopDone(error_t err){
  }
  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }
}
