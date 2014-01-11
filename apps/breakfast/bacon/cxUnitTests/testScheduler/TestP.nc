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
 #include "CXLink.h"
 #include "CXNetwork.h"
 //for invalid frame
 #include "CXScheduler.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;

  uses interface Packet;

  uses interface StdControl as SerialControl;
  
  //loopback down to scheduler: this role should be handled by an
  //AMReceiver, generally speaking
  provides interface Receive;
} implementation {
  bool started = FALSE;
  bool receivePending = FALSE;
  uint32_t reqFrame;
  int32_t reqOffset;

  message_t rxMsg_internal;
  message_t* rxMsg = &rxMsg_internal;

  message_t txMsg_internal;
  message_t* txMsg = &txMsg_internal;


  enum{
    PAYLOAD_LEN= 50,
  };

  typedef nx_struct test_payload {
    nx_uint16_t packetType;
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;


  task void usage(){
    printf("---- %s ID %u Commands ----\r\n", 
      CX_MASTER == 1?  "MASTER": "SLAVE", 
      TOS_NODE_ID);
    printf("S : toggle start/stop\r\n");
    printf("t : transmit a packet\r\n");
    printf("q : reset\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
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
      if (LINK_DEBUG_FRAME_BOUNDARIES || LINK_DEBUG_WAKEUP ){
        P1DIR |= BIT1;
        P1SEL &= ~BIT1;
        P1OUT &= ~BIT1;
      }else{
        P1SEL |= BIT1;
        P1DIR |= BIT1;
      }
      
      //power on flash chip to open p1.1-4
      P2SEL &=~BIT1;
      P2OUT |=BIT1;
      //enable p1.1,2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);

    }
  }

  task void toggleStartStop(){
    if (started){
      printf(" Stop %x \r\n", call SplitControl.stop());
    }else{
      printf(" Start %x \r\n", call SplitControl.start());
    }
  }

  task void receiveNext(){
    uint32_t nf = call CXRequestQueue.nextFrame(FALSE);
    error_t error = call CXRequestQueue.requestReceive(0,
      nf, 0,
      FALSE, 0,
      0, NULL, rxMsg);
    if (error != SUCCESS){
      printf("rn reqR: %x @%lu\r\n", error, nf);
    }
  }

  event void SplitControl.startDone(error_t error){
    printf("started %x \r\n", error);
    started = TRUE;
    post receiveNext();
  }

  event void SplitControl.stopDone(error_t error){
    printf("stopped %x\r\n", error);
    started = FALSE;
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_, bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, void* md, message_t* msg_){
    if (didReceive){
      uint8_t len = call Packet.payloadLength(msg_);
      printf("RX %p [%u]\r\n", msg_, len);
      if (((test_payload_t*)call Packet.getPayload(msg_, len))->packetType == 0xDCDC){
        printf("Test Packet RX\r\n");
      }else{
        rxMsg = signal Receive.receive(msg_, 
          call Packet.getPayload(msg_, len), 
          len);
      }
      post receiveNext();
    }else{
      if (error == SUCCESS || error == EBUSY){
        uint32_t nf = call CXRequestQueue.nextFrame(FALSE);
        error = call CXRequestQueue.requestReceive(0,
          nf, 0,
          FALSE, 0,
          0,
          NULL, msg_);
        if (SUCCESS != error){
          printf("rh reqR: %x @%lu\r\n", error, nf);
        }
      } else {
        printf("RX error: %x\r\n", error);
      }
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_, uint32_t microRef,
      uint32_t t32kRef,
      void* md, message_t* msg_){
    printf("send handled: %x %lu %lu %p\r\n", error, atFrame,
      microRef, msg_);
  }

  event void CXRequestQueue.sleepHandled(error_t error,
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_){ }

  event void CXRequestQueue.wakeupHandled(error_t error,
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_){
    if (error != SUCCESS){
      printf("wakeup handled: %x @ %lu req %lu\r\n", error, atFrame,
        reqFrame_);
    }
  }

  task void transmit(){
    test_payload_t* pl = 
      (test_payload_t*)(call Packet.getPayload(txMsg,
        sizeof(test_payload_t)));
    error_t error;
    uint32_t nextFrame;
    pl->packetType = 0xDCDC;
    {
      uint8_t i;
      for (i = 0; i < PAYLOAD_LEN; i++){
        pl->buffer[i] = i;
      }
    }
    call Packet.setPayloadLength(txMsg, sizeof(test_payload_t));
    nextFrame = call CXRequestQueue.nextFrame(TRUE);
    if (nextFrame != INVALID_FRAME){
      error = call CXRequestQueue.requestSend(0,
        nextFrame, 0,
        FALSE, 0, 
        &pl->timestamp,
        NULL, txMsg);
      printf("TX @%lu: %x\r\n", nextFrame, error);
    }else{
      printf("TX nf invalid\r\n");
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
       case '?':
         post usage();
         break;
       case 't':
         post transmit();
         break;
       case '\r':
         printf("\n");
         break;
       default:
         break;
     }
     printf("%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}

  default event message_t* Receive.receive(message_t* msg_, 
      void* payload, uint8_t len){
    return msg_;
  }
}

