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
module ScheduledTestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface AMSend;
  uses interface Receive;

  uses interface Packet;
  uses interface AMPacket;

  uses interface StdControl as SerialControl;

  uses interface ActiveMessageAddress;

  uses interface Timer<TMilli>;
  uses interface Random;

  uses interface SkewCorrection;
} implementation {
  uint32_t sn = 0;
  uint32_t outstanding = 0;
  bool filling = TRUE;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  message_t rx_msg;
  message_t* rxMsg = &rx_msg;
  test_payload_t* rx_pl;
  uint8_t rxPLL;

  bool started = FALSE;


  task void usage(){
    cinfo(test,"BOOTED %s ID %u \r\n",
          (CX_MASTER==1)?"MASTER": "SLAVE",
          call ActiveMessageAddress.amAddress());
  }
  
  task void toggleStartStop();
  task void transmit();

  event void Boot.booted(){
    post usage();
    post toggleStartStop();
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


  event void Timer.fired(){
    post transmit();
  }

  event void SplitControl.startDone(error_t error){
    cinfo(test,"Started %x \r\n", error);
    started = TRUE;
    if (TEST_TRANSMIT){
      call Timer.startOneShot(TEST_STARTUP_DELAY);
    }
  }

  event void SplitControl.stopDone(error_t error){
    cinfo(test,"Stopped %x\r\n", error);
    started = FALSE;
  }


  task void transmit(){
    test_payload_t* pl = call AMSend.getPayload(msg,
      sizeof(test_payload_t));
    uint8_t i;
    error_t error;
    call Packet.clear(msg);
    for (i=0; i < PAYLOAD_LEN; i++){
      pl->buffer[i] = i;
    }
    pl -> timestamp = 0xBABEFACE;
    pl -> sn = sn++;
    error = call AMSend.send(TEST_DESTINATION, msg, sizeof(test_payload_t));
    cinfo(test,"APP TX %lu to %u %u %x\r\n", 
      pl->sn, call AMPacket.destination(msg), 
      sizeof(test_payload_t), error);
    if (error != SUCCESS){
      call Timer.startOneShot(TEST_IPI/2 + 
        call Random.rand16()%TEST_IPI);
    }
  }

  event void AMSend.sendDone(message_t* msg_, error_t error){
    test_payload_t* pl = call AMSend.getPayload(msg_,
      sizeof(test_payload_t));
    uint32_t fn = (TEST_FRAME_BASE + sn%TEST_FRAME_RANGE);
    uint32_t offset = TOS_NODE_ID%32UL;
    cinfo(test,"APP TXD %lu to %u %x Q %lu\r\n", 
      pl->sn, 
      call AMPacket.destination(msg_),
      error,
      outstanding);
    //Goal here is to have nodes attempt to TX at various points in
    //  the global cycle. 
    //- each frame is 32 bms long, so TOS_NODE_ID gives the node an
    //  offset within the frame to try the send.
    //- TEST_FRAME_BASE + sn%TEST_FRAME_RANGE gives the frame number
    //  which we send in. (*32 to get it in ms).
    // - So, if TEST_FRAME_BASE is 500 and TEST_FRAME_RANGE is 100,
    //   node 3 would call Send at 500.3, 501.3, ... 599.3, 500.3
    call Timer.startOneShotAt(
      (call SkewCorrection.referenceTime(0))/32UL,
      32UL*fn+ offset);
    cinfo(test, "STX @%lu %lu + %lu.%lu (%lu)\r\n", 
      call Timer.getNow(),
      (call SkewCorrection.referenceTime(0))/32UL,
      fn,
      offset, 
      (32UL*fn) + offset);
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
    cinfo(test,"APP RX %u %lu\r\n", 
      call AMPacket.source(rxMsg), rx_pl->sn);
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


  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       #if TEST_TRANSMIT == 0
       case 't':
         post transmit();
         break;
       #endif
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

