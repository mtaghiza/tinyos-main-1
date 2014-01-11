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

/**
 * Test CXTDMA AODV component
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "message.h"
#include "CXTDMA.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface SplitControl;
  uses interface AMPacket;
  uses interface Packet;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Send;
  uses interface Receive;

  uses interface Leds;

} implementation {
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  norace uint8_t tx_len;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;

  typedef nx_struct test_packet_t{
    nx_uint32_t sn;
  } test_packet_t;
  
  //schedule info
  uint16_t _framesPerSlot;
  
  norace bool isTransmitting = FALSE;
  norace bool broadcasting = FALSE;

  task void printStatus(){
    printf("----\r\n");
    printf("ID: %u\r\n", TOS_NODE_ID);
    printf("is root: %x\r\n", TDMA_ROOT);
    printf("is transmitting: %x\r\n", isTransmitting);
  }

  event void Boot.booted(){
    atomic{
      //timing pins
      P1SEL &= ~(BIT1|BIT3|BIT4);
      P1SEL |= BIT2;
      P1DIR |= (BIT1|BIT2|BIT3|BIT4);
      P2SEL &= ~(BIT4);
      P2DIR |= (BIT4);
      //set up SFD GDO on 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
      
      P1OUT &= ~(BIT1|BIT3|BIT4);
      P2OUT &= ~(BIT4);
      
      //odd behavior: flash chip seems to drive the SPI lines to gnd
      //when it's powered off.
      P2SEL &=~BIT1;
      P2OUT |=BIT1;
    }
    call UartControl.start();
    printf("\r\nCXTDMA AODV test\r\n");
    printf("s: start \r\n");
    printf("S: stop \r\n");
    printf("t: toggle is-transmitting unicast\r\n");
    printf("T: toggle is-transmitting broadcast\r\n");
    printf("X: send one broadcast\r\n");
    printf("x: send one unicast\r\n");
    printf("?: print status\r\n");
    printf("========================\r\n");
    post printStatus();
//    call SplitControl.start();
  }


  event void SplitControl.startDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  event void SplitControl.stopDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  task void broadcastTask(){
    error_t error;
    test_packet_t* pl = call Packet.getPayload(tx_msg,
      sizeof(test_packet_t));
    call CXPacket.setDestination(tx_msg, AM_BROADCAST_ADDR);
    pl -> sn ++;//= (1+TOS_NODE_ID);
    //TODO: where should am header be accounted for?
    error = call Send.send(tx_msg, sizeof(test_packet_t) +
      sizeof(rf1a_nalp_am_t));
    printf("Send.Send (broadcast): %s\r\n", decodeError(error));
  }

  task void unicastTask(){
    error_t error;
    test_packet_t* pl = call Packet.getPayload(tx_msg,
      sizeof(test_packet_t));
    call CXPacket.setDestination(tx_msg, 0);
    pl -> sn ++;//= (1+TOS_NODE_ID);
    error = call Send.send(tx_msg, sizeof(test_packet_t) +
      sizeof(rf1a_nalp_am_t));
    printf("Send.Send (unicast): %s\r\n", decodeError(error));
  }

  event void Send.sendDone(message_t* msg, error_t error){
    printf("SD %x %lu @%lu\r\n",
      TOS_NODE_ID,
      ((test_packet_t*)call Packet.getPayload(msg, sizeof(test_packet_t)))->sn,
      call CXPacket.getTimestamp(msg));
    if (SUCCESS != error){
      printf("!sd %x\r\n", error);
    }else{
      if (isTransmitting){
        if (broadcasting){
          post broadcastTask();
        }else {
          post unicastTask();
        }
      }
    }
//      printf("DSD %x\r\n", error);
  }

  task void startTask(){
    error_t error = call SplitControl.start();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
    post printStatus();
  }

  task void stopTask(){
    error_t error = call SplitControl.stop();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
    post printStatus();
  }

  task void toggleTX(){
    isTransmitting = !isTransmitting;
    if (isTransmitting){
      if (broadcasting){
        post broadcastTask();
      } else {
        post unicastTask();
      }
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 's':
        printf("Starting\r\n");
        post startTask();
        break;
      case 'S':
        printf("Stopping\r\n");
        post stopTask();
        break;
      case '?':
        post printStatus();
        break;
      case 't':
        broadcasting = FALSE;
        printf("Toggle TX\r\n");
        post toggleTX();
        break;
      case 'T':
        broadcasting = TRUE;
        printf("Toggle TX\r\n");
        post toggleTX();
        break;
      case 'x':
        post unicastTask();
        break;
      case 'X':
        post broadcastTask();
        break;
      case '\r':
        printf("\r\n");
        break;
     default:
        printf("%c", byte);
        break;
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    printf("RX %x sn %lu rc %u @%lu\r\n", 
      call CXPacket.source(msg),
      ((test_packet_t*)payload)->sn,
      call CXPacketMetadata.getReceivedCount(msg),
      call CXPacketMetadata.getPhyTimestamp(msg));
    return msg;
  }

  //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
