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
#include "SchedulerDebug.h"
#include "test.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface SplitControl;
  uses interface AMPacket;
  uses interface Packet;
  uses interface CXPacket;
  uses interface Rf1aPacket;
  uses interface CXPacketMetadata;

  uses interface AMSend;
  uses interface Receive;

  uses interface Leds;
  uses interface Timer<TMilli> as StartupTimer;
  uses interface Timer<TMilli> as SendTimer;

  uses interface Random;

} implementation {
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  norace uint8_t tx_len;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  bool sending;

  typedef nx_struct test_packet_t{
    nx_uint32_t sn;
  } test_packet_t;

  uint16_t packetQueue = 0;
  
  task void unicastTask();
  task void broadcastTask();
  task void sendTask();
  task void startTask();

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
    printf_APP("Booted.\r\n");
    #if DESKTOP_TEST == 0
//    printf("starting\r\n");
    post startTask();
    #else
    if (TOS_NODE_ID != 0){
      post startTask();
    }
    #endif
  }
  
  event void SendTimer.fired(){
    packetQueue++;
    printf_TEST_QUEUE("Queue Length: %u ", packetQueue);
    if (packetQueue >= QUEUE_THRESHOLD){
      printf_TEST_QUEUE("send\r\n");
      post sendTask();
    }else{
      printf_TEST_QUEUE("wait\r\n");
    }

    call SendTimer.startOneShot((TEST_IPI/2) + 
      (call Random.rand32())%TEST_IPI );
  }

  event void StartupTimer.fired(){
    printf_TESTBED("Begin transmissions\r\n");
    call SendTimer.startOneShot((TEST_IPI/2) + 
      (call Random.rand32())%TEST_IPI );
  }

  event void SplitControl.startDone(error_t error){
//    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
//    call AMPacket.clear(tx_msg);
    printf_APP("Started.\r\n");
    call Leds.led0On();
    if (TOS_NODE_ID != 0){
      #if IS_SENDER == 1
        #if DESKTOP_TEST == 0
        call StartupTimer.startOneShot(TESTBED_START_TIME);
        #else
        call StartupTimer.startOneShot(DESKTOP_START_TIME);
        #endif
      #endif
    }
  }

  event void SplitControl.stopDone(error_t error){
    printf_APP("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  task void broadcastTask(){
    error_t error;
    test_packet_t* pl = call Packet.getPayload(tx_msg,
      sizeof(test_packet_t));
    pl -> sn ++;//= (1+TOS_NODE_ID);

    error = call AMSend.send(AM_BROADCAST_ADDR, tx_msg,
      sizeof(test_packet_t)); 
      
    if (SUCCESS == error){
      sending = TRUE;
    }else{
      printf("Send.Send (broadcast): %s\r\n", decodeError(error));
    }
  }

  task void unicastTask(){
    error_t error;
    test_packet_t* pl = call Packet.getPayload(tx_msg,
      sizeof(test_packet_t));
    pl -> sn ++;//= (1+TOS_NODE_ID);
    error = call AMSend.send(0, tx_msg, sizeof(test_packet_t));
    if (SUCCESS == error){
      sending = TRUE;
    }else{
      printf("Send.Send (unicast): %s\r\n", decodeError(error));
    }
  }

  task void sendTask(){
    if (!sending){
      #if FLOOD_TEST == 1
      post broadcastTask();
      #else 
      post unicastTask();
      #endif
    }
  }


  event void AMSend.sendDone(message_t* msg, error_t error){
    call Leds.led1Toggle();
    sending = FALSE;
    printf_APP("TX s: %u d: %u sn: %u rm: %u pr: %u e: %u\r\n",
      TOS_NODE_ID,
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      (call CXPacket.getNetworkProtocol(msg)) & ~CX_RM_PREROUTED,
      ((call CXPacket.getNetworkProtocol(msg)) & CX_RM_PREROUTED)?1:0,
      error);
    if (packetQueue){
      packetQueue--;
    }
    if (error == ENOACK || error == SUCCESS){
      if (packetQueue){
        post sendTask();
      }
    } else {
      printf("!sd %s\r\n", decodeError(error));
    }
  }

  task void startTask(){
    error_t error = call SplitControl.start();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    call Leds.led2Toggle();
    printf_APP("RX s: %u d: %u sn: %u c: %u r: %d l: %u\r\n", 
      call CXPacket.source(msg),
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      call CXPacketMetadata.getReceivedCount(msg),
      call Rf1aPacket.rssi(msg),
      call Rf1aPacket.lqi(msg)
      );
    return msg;
  }
  async event void UartStream.receivedByte(uint8_t byte){ 
    #if DESKTOP_TEST == 1
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 's':
        post startTask();
        break;
      default:
    }
    #endif
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
