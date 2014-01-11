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
  uses interface Timer<TMilli> as SendTimeout;

  uses interface Random;
  uses interface PacketAcknowledgements;

  uses interface CXRoutingTable;

} implementation {
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  norace uint8_t tx_len;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  bool sending;

  #if RF1A_FEC_ENABLED == 1
  #define PADDING_LEN 0
  #else
  //padding length: equal to the length of the FEC-protected portion
  //of the packet (headers, 4-byte sn, encoded(2-byte CRC))
  #define PADDING_LEN (sizeof(ieee154_header_t) + sizeof(cx_header_t) + sizeof(rf1a_nalp_am_t)  + sizeof(nx_uint32_t) + 2*sizeof(uint16_t))
  #endif

  typedef nx_struct test_packet_t{
    nx_uint32_t sn;
    nx_uint8_t padding[PADDING_LEN];
  } test_packet_t;

  uint16_t packetQueue = 0;
  
  task void sendTask();
  task void startTask();

  #ifndef TEST_DEST_ADDR
  #define TEST_DEST_ADDR AM_BROADCAST_ADDR
  #endif

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
    //in case we were mid-printf when we got programmed last
    printf_APP("\r\n\r\n");
    printf_APP("START %s\r\n", TEST_DESC);
    call StartupTimer.startOneShot((call Random.rand32())%5120);
  }
  
  event void SendTimer.fired(){
    packetQueue++;
//    printf_TEST_QUEUE("Queue Length: %u ", packetQueue);
    if (packetQueue >= QUEUE_THRESHOLD){
//      printf_TEST_QUEUE("send\r\n");
      post sendTask();
    }else{
//      printf_TEST_QUEUE("wait\r\n");
    }
    
    #if RANDOMIZE_IPI == 1
      call SendTimer.startOneShot((TEST_IPI/2) + 
        (call Random.rand32())%TEST_IPI );
    #else
      call SendTimer.startOneShot(TEST_IPI);
    #endif
  }

  event void StartupTimer.fired(){
    printf_TESTBED("Starting.\r\n");
    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t error){
//    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
//    call AMPacket.clear(tx_msg);
    printf_APP("Started.\r\n");
    call Leds.led0On();
    #if IS_SENDER == 1
      printf_APP("Start sending.\r\n");
      packetQueue = 0;
      #if RANDOMIZE_IPI == 1
        call SendTimer.startOneShot(TX_START_DELAY + ((TEST_IPI/2) + 
          (call Random.rand32())%TEST_IPI) );
      #else
        call SendTimer.startOneShot(TX_START_DELAY + TEST_IPI);
      #endif
    #endif
  }

  event void SplitControl.stopDone(error_t error){
    printf_APP("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  task void sendTask(){
    if (!sending){
      uint8_t i;
      error_t error;
      test_packet_t* pl = call Packet.getPayload(tx_msg,
        sizeof(test_packet_t));
      pl -> sn ++;//= (1+TOS_NODE_ID);
      for (i =0 ; i < PADDING_LEN; i++){
        pl->padding[i] = 0xDC;
      }

      #if TEST_REQUEST_ACK == 1
      call PacketAcknowledgements.requestAck(tx_msg);
      #endif
      error = call AMSend.send(TEST_DEST_ADDR, tx_msg,
        sizeof(test_packet_t)); 
        
      if (SUCCESS == error){
        sending = TRUE;
      }else{
        printf("Send.Send: %s\r\n", decodeError(error));
      }
    }
  }

  event void SendTimeout.fired(){
    if (sending){
      error_t err = call AMSend.cancel(tx_msg);
      if (err != SUCCESS){
        printf_TMP("TO CANCEL: %s\r\n", decodeError(err));
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    call Leds.led1Toggle();
    sending = FALSE;
    if (call SendTimeout.isRunning()){
      call SendTimeout.stop();
    }
    if (error == ENOACK || error == SUCCESS){
      if (packetQueue){
        packetQueue--;
      }
      //try to drain it until we hit a delay
      if (packetQueue){
        call SendTimeout.startOneShot(APP_SEND_TIMEOUT);
        post sendTask();
      }
    } else if (error == ECANCEL){
      //OK: we should see this when we cancel to keep IPI steady
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
//    uint8_t i;
    call Leds.led2Toggle();
//    printf_APP("[");
//    for (i=0; i < TOSH_DATA_LENGTH+sizeof(message_header_t); i++){
//      printf_APP("%02X", msg->header[i]);
//    }
//    printf_APP("]");
//    printf_APP("\r\n");
//    printf_APP("(");
//    if (payload != NULL){
//      for (i=0; i < len; i++){
//        printf_APP("%02X", ((uint8_t*)payload)[i]);
//      }
//    } else{
//      printf_APP("NULL");
//    }
//    printf_APP(")");
//    printf_APP("\r\n");
//    printf_APP("rx %p %u calc %p %u\r\n", 
//      payload, 
//      len, 
//      call Packet.getPayload(msg, sizeof(test_packet_t)),
//      call Packet.payloadLength(msg));
//
    return msg;
  }

  task void dumpTableTask(){
    call CXRoutingTable.dumpTable();
  }
  async event void UartStream.receivedByte(uint8_t byte){ 
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 'd':
        post dumpTableTask();
        break;
      default:
    }
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
