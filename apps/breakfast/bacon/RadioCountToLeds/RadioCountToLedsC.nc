// $Id: RadioCountToLedsC.nc,v 1.7 2010-06-29 22:07:17 scipio Exp $
/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
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
 * - Neither the name of the University of California nor the names of
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
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
 
#include "Timer.h"
#include "RadioCountToLeds.h"
#include <stdio.h>
 
/**
 * Implementation of the RadioCountToLeds application. RadioCountToLeds 
 * maintains a 4Hz counter, broadcasting its value in an AM packet 
 * every time it gets updated. A RadioCountToLeds node that hears a counter 
 * displays the bottom three bits on its LEDs. This application is a useful 
 * test to show that basic AM communication and timers work.
 *
 * @author Philip Levis
 * @date   June 6 2005
 */

module RadioCountToLedsC @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface Random;
//    interface DelayedSend;
//    interface Timer<TMilli> as DelayTimer;
  }
  uses interface StdControl as SerialControl;
  uses interface UartStream;
//  uses interface Rf1aDumpConfig;
  uses interface Rf1aPhysical;
  uses interface Rf1aPacket;
  uses interface HplMsp430Rf1aIf;
//  uses interface Rf1aConfigure;
}
implementation {

  message_t packet;

  bool locked;
  uint16_t counter = 0;
  
  event void Boot.booted() {
    P1SEL &= ~(BIT1|BIT2|BIT3|BIT4);
    P1OUT &= ~(BIT1|BIT2|BIT3|BIT4);
    P1DIR |= (BIT1|BIT2|BIT3|BIT4);
    P2SEL &= ~(BIT4);
    P2OUT &= ~(BIT4);
    P2DIR |= BIT4;
    call AMControl.start();
    call SerialControl.start();
    printf("Booted\n");
  }

  event void AMControl.startDone(error_t err) {
//    call Rf1aDumpConfig.display(call Rf1aConfigure.getConfiguration());
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call HplMsp430Rf1aIf.writeSinglePATable(TEST_POWER);
    if (err == SUCCESS) {
      printf("Starting\n");
      #if IS_SENDER == 1
      call MilliTimer.startOneShot(10*TEST_IPI + 
        call Random.rand16()%(10*TEST_IPI_RAND));
      #endif
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void MilliTimer.fired() {
    error_t error;
    counter++;
//    printf(".");
    dbg("RadioCountToLedsC", "RadioCountToLedsC: timer fired, counter is %hu.\n", counter);
    if (locked) {
      return;
    }
    else {
      radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(radio_count_msg_t));
      if (rcm == NULL) {
	return;
      }

      rcm->counter = counter;
      error = call AMSend.send(AM_BROADCAST_ADDR, &packet,
        sizeof(radio_count_msg_t));
      if (error == SUCCESS) {
        dbg("RadioCountToLedsC", "RadioCountToLedsC: packet sent.\n", counter);	
        locked = TRUE;
      }
//      printf("TX %u\r\n", TOS_NODE_ID);
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
    dbg("RadioCountToLedsC", "Received packet of length %hhu.\n", len);
    if (len != sizeof(radio_count_msg_t)) {return bufPtr;}
    else {
      radio_count_msg_t* rcm = (radio_count_msg_t*)payload;
      printf("RX %u %u %d %d %u\n", 
        call AMPacket.source(bufPtr),
        TOS_NODE_ID,
        call Rf1aPacket.rssi(bufPtr),
        call Rf1aPacket.lqi(bufPtr),
        rcm->counter);
      if (rcm->counter & 0x1) {
	call Leds.led0On();
      }
      else {
	call Leds.led0Off();
      }
      if (rcm->counter & 0x2) {
	call Leds.led1On();
      }
      else {
	call Leds.led1Off();
      }
      if (rcm->counter & 0x4) {
	call Leds.led2On();
      }
      else {
	call Leds.led2Off();
      }
      return bufPtr;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr) {
      locked = FALSE;
    }
    #if IS_SENDER==1
      call MilliTimer.startOneShot(TEST_IPI + call Random.rand16()%TEST_IPI_RAND);
    #endif
//    printf("+");
//    printf("Send Done: %x\n\r", error);
//    printf("\n\r\n\r");
  }

//  async event void DelayedSend.sendReady(){
////    printf("-");
////    if (DELAY){
////      call DelayTimer.startOneShot(10);
////    } else {
//      signal DelayTimer.fired();
////    }
//  }
//
//  event void DelayTimer.fired(){
////    printf("Completing\n\r");
//    call DelayedSend.completeSend();
//  }
//
  async event void UartStream.receivedByte(uint8_t byte){
//    switch(byte){
//      case 'q':
//        WDTCTL=0;
//        break;
//      case 't':
//        if (call MilliTimer.isRunning()){
//          call MilliTimer.stop();
//          printf("STOP\n\r");
//        }else{
//          call MilliTimer.startPeriodic(1024);
//          printf("START\n\r");
//        }
//        break;
//      case '\r':
//        printf("\n\r");
//        break;
//      default:
//        printf("%c", byte);
//        break;
//    }
  }

  //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

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




