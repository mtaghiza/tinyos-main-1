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
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface Random;
//    interface DelayedSend;
//    interface Timer<TMilli> as DelayTimer;
  }
  uses interface Timer<TMilli> as SendTimer;
  uses interface StdControl as SerialControl;
  uses interface UartStream;
  uses interface Rf1aDumpConfig;
  uses interface Rf1aPhysical;
  uses interface Rf1aPacket;
  uses interface HplMsp430Rf1aIf;
  uses interface StdControl as CC1190Control;
  uses interface CC1190;

  uses interface Rf1aStatus;
//  uses interface Rf1aConfigure;
}
implementation {
  #ifndef AUTOSEND
  #define AUTOSEND 0
  #endif

  #ifndef SEND_INTERVAL
  #define SEND_INTERVAL 100
  #endif

  message_t packet;

  bool locked;
  uint16_t counter = 0;
  
  event void Boot.booted() {
    atomic{
      P1SEL &= ~(BIT1|BIT2|BIT3|BIT4);
      P1OUT &= ~(BIT1|BIT2|BIT3|BIT4);
      P1DIR |= (BIT1|BIT2|BIT3|BIT4);
      P2SEL &= ~(BIT4);
      P2OUT &= ~(BIT4);
      P2DIR |= BIT4;

      P2SEL |= BIT4;
      
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
    }

    call AMControl.start();
    call SerialControl.start();
    printf("CONNECTIVITY %s\r\n", TEST_DESC);
  }

  event void AMControl.startDone(error_t err) {
    rf1a_config_t config;
    //Assume the amp is present, power + HGM
    call CC1190Control.start();
    //Set amp to TX mode if autosend is on.
    if (AUTOSEND == 1){
      call CC1190.TXMode(TRUE);
    }else{
      call CC1190.RXMode(TRUE);
    }

    printf("P3DIR: %x P3SEL: %x P3OUT: %x\r\n", P3DIR, P3SEL, P3OUT);
    printf("PJDIR: %x PJOUT: %x\r\n", PJDIR, PJOUT);
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call Rf1aPhysical.setPower(TEST_POWER);
    call Rf1aPhysical.readConfiguration(&config);
    call Rf1aDumpConfig.display(&config);
    printf("Started %x\r\n", err);
    if (err == SUCCESS) {
      if (AUTOSEND){
        call SendTimer.startOneShot(SEND_INTERVAL);
      }
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }

  task void doSend(){
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
      call Rf1aPhysical.setPower(TEST_POWER);
      call Packet.clear(&packet);
      rcm->counter = counter;
      error = call AMSend.send(AM_BROADCAST_ADDR, &packet,
        sizeof(radio_count_msg_t));
      if (error == SUCCESS) {
        dbg("RadioCountToLedsC", "RadioCountToLedsC: packet sent.\n", counter);	
        locked = TRUE;
      }
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
    dbg("RadioCountToLedsC", "Received packet of length %hhu.\n", len);
    {
      radio_count_msg_t* rcm = (radio_count_msg_t*)payload;
      printf("RX %u %u %u %u %u %u %lu %d %d %x\r\n",
        TEST_SR,
        TEST_POWER,
        call Packet.payloadLength(bufPtr) + sizeof(rf1a_nalp_am_t)+sizeof(rf1a_ieee154_t),
        call AMPacket.source(bufPtr),
        call AMPacket.destination(bufPtr),
        TOS_NODE_ID,
        rcm->counter,
        call Rf1aPacket.rssi(bufPtr),
        call Rf1aPacket.lqi(bufPtr),
        call Rf1aPacket.crcPassed(bufPtr)
      );
//      printf("RX %u %u %lu %d %d \r\n", 
//        call AMPacket.source(bufPtr),
//        TOS_NODE_ID,
//        rcm->counter, 
//        call Rf1aPacket.rssi(bufPtr),
//        call Rf1aPacket.lqi(bufPtr));
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
    radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(radio_count_msg_t));
    printf("TX %u %u %u %u %u %lu\r\n", 
      TEST_SR,
      TEST_POWER,
      call Packet.payloadLength(bufPtr) + sizeof(rf1a_nalp_am_t)+sizeof(rf1a_ieee154_t),
      call AMPacket.source(bufPtr),
      call AMPacket.destination(bufPtr),
      rcm->counter);
    if (&packet == bufPtr) {
      locked = FALSE;
    }
    if (AUTOSEND){
      call SendTimer.startOneShot(TEST_IPI);
    }
      if (counter & 0x1) {
	call Leds.led0On();
      }
      else {
	call Leds.led0Off();
      }
      if (counter & 0x2) {
	call Leds.led1On();
      }
      else {
	call Leds.led1Off();
      }
      if (counter & 0x4) {
	call Leds.led2On();
      }
      else {
	call Leds.led2Off();
      }
//    printf("+");
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

  task void readStatus(){
    rf1a_config_t config;
    
    printf("status: %x\r\n", call Rf1aStatus.get());
    call Rf1aPhysical.readConfiguration(&config);
    call Rf1aDumpConfig.display(&config);
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 't':
        post doSend();
        break;
      case '?':
        post readStatus();
        break;
      case '\r':
        printf("\r\n");
        break;
      default:
        printf("%c", byte);
        break;
    }
  }

  event void SendTimer.fired(){
    post doSend();
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




