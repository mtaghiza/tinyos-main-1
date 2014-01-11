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
 #include "CXTransport.h"
 #include "test.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface AMSend as BroadcastAMSend;
  uses interface AMSend as UnicastAMSend;
  uses interface ScheduledAMSend;
  uses interface Receive;

  uses interface Packet;
  uses interface AMPacket;

  uses interface StdControl as SerialControl;

  uses interface ActiveMessageAddress;
} implementation {
  uint32_t sn = 0;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  message_t msg_internal2;
  message_t* msg2 = &msg_internal2;

  message_t rx_msg;
  message_t* rxMsg = &rx_msg;
  test_payload_t* rx_pl;
  uint8_t rxPLL;

  bool started = FALSE;

  bool continuousTXBroadcast = FALSE;
  bool continuousTXUnicast = FALSE;


  task void usage(){
    cinfo(test,"---- %s ID %x Commands ----\r\n",
          (CX_MASTER==1)?"MASTER": "SLAVE",
          call ActiveMessageAddress.amAddress());
    cinfo(test,"S : toggle start/stop\r\n");
    cinfo(test,"b : transmit a packet broadcast\r\n");
    cinfo(test,"B : toggle broadcast transmit back-to-back\r\n");
    cinfo(test,"u : transmit a packet unicast\r\n");
    cinfo(test,"U : toggle unicast transmit back-to-back\r\n");
    cinfo(test,"q : reset\r\n");

  }

  event void Boot.booted(){
    cinfo(test,"Booted.\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      P1MAP1 = PM_SMCLK;
      PMAPPWD = 0x00;
      
      P2DIR |= BIT4;
      P2SEL |= BIT4;
//      if (LINK_DEBUG_FRAME_BOUNDARIES){
        P1DIR |= BIT1;
        P1SEL &= ~BIT1;
        P1OUT &= ~BIT1;
//      }else{
//        P1SEL |= BIT1;
//        P1DIR |= BIT1;
//      }
      
      //power on flash chip to open p1.1-4
      P2SEL &=~BIT1;
      P2OUT |=BIT1;

      //enable p1.2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);

    }
  }

  task void toggleStartStop(){
    if (started){
      error_t error = call SplitControl.stop(); 
      cinfo(test," Stop %x \r\n", error);
    }else{
      error_t error = call SplitControl.start(); 
      cinfo(test," Start %x \r\n", error);
    }
  }

  event void SplitControl.startDone(error_t error){
    cinfo(test,"Started %x \r\n", error);
    started = TRUE;
  }

  event void SplitControl.stopDone(error_t error){
    cinfo(test,"Stopped %x\r\n", error);
    started = FALSE;
  }


  task void broadcast(){
    test_payload_t* pl = call BroadcastAMSend.getPayload(msg,
      sizeof(test_payload_t));
    uint8_t i;
    error_t error;
    call Packet.clear(msg);
    for (i=0; i < PAYLOAD_LEN; i++){
      pl->buffer[i] = i;
    }
    pl -> timestamp = 0xBABEFACE;
    pl -> sn = sn++;
    error = call BroadcastAMSend.send(AM_BROADCAST_ADDR, msg, sizeof(test_payload_t));
    cinfo(test,"APP TX %lu to %x %u %x\r\n", 
      pl->sn, AM_BROADCAST_ADDR, 
      sizeof(test_payload_t), error);
  }

  task void unicast(){
    test_payload_t* pl = call UnicastAMSend.getPayload(msg2,
      sizeof(test_payload_t));
    uint8_t i;
    error_t error;
    call Packet.clear(msg2);
    for (i=0; i < PAYLOAD_LEN; i++){
      pl->buffer[i] = i;
    }
    pl -> timestamp = 0xBABEFACE;
    pl -> sn = sn++;
    error = call UnicastAMSend.send(DESTINATION_ID, msg2, sizeof(test_payload_t));
    cinfo(test,"APP TX %lu to %x %u %x\r\n", 
      pl->sn, 
      DESTINATION_ID, 
      sizeof(test_payload_t), 
      error);
  }
  
  uint8_t packetBCIndex;

  task void printBCPacket(){
    if (packetBCIndex < sizeof(message_header_t) + TOSH_DATA_LENGTH){
      cdbg(test, "+ %u %x\r\n", 
        packetBCIndex, msg->header[packetBCIndex]);
      packetBCIndex++;
      post printBCPacket();
    }
  }

  event void BroadcastAMSend.sendDone(message_t* msg_, error_t error){
    test_payload_t* pl = call BroadcastAMSend.getPayload(msg_,
      sizeof(test_payload_t));
    cinfo(test,"APP TXD %lu to %x %x\r\n", 
      pl->sn, 
      call AMPacket.destination(msg_),
      error);
    if (continuousTXBroadcast){
      post broadcast();
    }else{
      packetBCIndex = 0;
      post printBCPacket();
    }
  }

  event void UnicastAMSend.sendDone(message_t* msg_, error_t error){
    test_payload_t* pl = call BroadcastAMSend.getPayload(msg_,
      sizeof(test_payload_t));
    cinfo(test,"APP TXD %lu to %x %x\r\n", 
      pl->sn, 
      call AMPacket.destination(msg_),
      error);

    if (continuousTXUnicast){
      post unicast();
    }
  }

  event void ScheduledAMSend.sendDone(message_t* msg_, error_t error){
  }

  uint8_t packetRXIndex;
  
  task void printRXPacket(){
    if (packetRXIndex < sizeof(message_header_t) + TOSH_DATA_LENGTH){
      cdbg(test, "+ %u %x\r\n", 
        packetRXIndex, rxMsg->header[packetRXIndex]);
      packetRXIndex++;
      post printRXPacket();
    }else{
      rx_pl = NULL;
    }
  }

  task void reportRX(){
    cinfo(test,"APP RX %lu %u\r\n", rx_pl->sn, rxPLL);
    cdbg(test, "++++\r\n");
    packetRXIndex=0;
    post printRXPacket();
  }

  event message_t* Receive.receive(message_t* msg_, 
      void* payload, uint8_t len){
    if (rx_pl != NULL){
      cwarn(test,"Still logging\r\n");
      return msg_;
    } else {
      message_t* ret = rxMsg;
      rxMsg = msg_;
      rx_pl = (test_payload_t*) payload;
      rxPLL = len;
      post reportRX();
      return ret;
    }
  }

  task void toggleTXBroadcast(){
    continuousTXBroadcast = !continuousTXBroadcast;
    if (continuousTXBroadcast){
      post broadcast();
    }
  }

  task void toggleTXUnicast(){
    continuousTXUnicast = !continuousTXUnicast;
    if (continuousTXUnicast){
      post unicast();
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 'b':
         post broadcast();
         break;
       case 'B':
         post toggleTXBroadcast();
         break;
       case 'u':
         post unicast();
         break;
       case 'U':
         post toggleTXUnicast();
         break;
       case '?':
         post usage();
         break;
       case '\r':
         cinfo(test,"\n");
         break;
       default:
         break;
     }
     cinfo(test,"%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void ActiveMessageAddress.changed(){}
}

