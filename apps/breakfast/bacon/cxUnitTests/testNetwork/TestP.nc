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

module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;

  uses interface Packet;
  uses interface CXNetworkPacket;

  uses interface StdControl as SerialControl;
} implementation {
  bool started = FALSE;
  bool forwarding = FALSE;
  bool receivePending = FALSE;
  uint32_t reqFrame;
  int32_t reqOffset;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  enum{
    PAYLOAD_LEN= 50,
  };

  typedef nx_struct test_payload {
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;

  task void requestShortReceive();

  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop + wakeup at startDone\r\n");
    printf("r : request long-duration receive\r\n");
    printf("f : toggle repeated short-duration receive/forward\r\n");
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
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL &= ~BIT1;
      P1OUT &= ~BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      
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

  event void SplitControl.startDone(error_t error){
    printf("started %x \r\n", error);
    started = TRUE;
    printf("wakeup req %x\r\n", 
      call CXRequestQueue.requestWakeup(0,
        call CXRequestQueue.nextFrame(FALSE), 0));
  }

  event void SplitControl.stopDone(error_t error){
    printf("stopped %x\r\n", error);
    started = FALSE;
  }

  event void CXRequestQueue.frameShiftHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame_){ }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame_, bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, void* md, message_t* msg_){
    if (!forwarding || error != SUCCESS || didReceive){
      printf("rx handled: %x %u @ %lu req %lu %x %lu\r\n",
        error, layerCount, atFrame, reqFrame_, didReceive, microRef);
      if (didReceive){
        printf("RX PL [%u]\r\n", call Packet.payloadLength(msg_));
      }
    }
    receivePending = FALSE;
    if (forwarding){
      if (!didReceive){
        //nothing: try to receive at next frame.
        reqFrame = atFrame;
        reqOffset = 1;
      }else{
        //atFrame is the frame in which we actually received the
        //packet. Since we also forwarded it, atFrame+1 is in the
        //past. hmmm.
        reqFrame = call CXRequestQueue.nextFrame(FALSE);
        reqOffset = 1;
        printf("rrx %lu %li\r\n", reqFrame, reqOffset);
      }
      post requestShortReceive();
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame_, uint32_t microRef,
      uint32_t t32kRef,
      void* md, message_t* msg_){
    printf("send handled: %x %u %lu %lu %p\r\n", error, layerCount, atFrame,
      microRef, msg_);
  }

  event void CXRequestQueue.sleepHandled(error_t error,
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame_){ }

  event void CXRequestQueue.wakeupHandled(error_t error,
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame_){
    printf("wakeup handled: %x %u @ %lu req %lu\r\n", error,
      layerCount, atFrame,
      reqFrame_);
  }

  void requestReceive(uint32_t duration, 
      uint32_t baseFrame, 
      int32_t frameOffset){
    error_t error = call CXRequestQueue.requestReceive(0,
      baseFrame, frameOffset, 
      FALSE, 0,
      duration,
      NULL, msg);
    if (SUCCESS == error){
      receivePending = TRUE;
    }else{
      printf("rx req %lu %li: %x\r\n", baseFrame, frameOffset, error);
    }
  }

  task void requestLongReceive(){
    printf("request long\r\n");
    requestReceive(RX_MAX_WAIT >> 5, 
      call CXRequestQueue.nextFrame(FALSE), 
      1);
  }

  task void requestShortReceive(){
    requestReceive(0, reqFrame, reqOffset);
  }

  task void toggleForward(){
    if (forwarding){
      printf("forwarding off\r\n");
      forwarding = FALSE;
    } else {
      printf("forwarding on\r\n");
      forwarding = TRUE;
      reqFrame = call CXRequestQueue.nextFrame(FALSE);
      reqOffset = 1;
      if (!receivePending){
        post requestShortReceive();
      }
    }
  }

  task void transmit(){
    test_payload_t * pl = (test_payload_t*)call Packet.getPayload(msg, sizeof(test_payload_t));
    if (pl != NULL){
      error_t error;
      uint8_t i;

      call CXNetworkPacket.init(msg);
      call CXNetworkPacket.setTTL(msg, 4);
      for (i = 0; i < PAYLOAD_LEN; i++){
        pl->buffer[i] = i;
      }
      printf("Set PL to [%u]", sizeof(test_payload_t));
      call Packet.setPayloadLength(msg, sizeof(test_payload_t));
      printf("Verify PL [%u]", call Packet.payloadLength(msg));

      error = call CXRequestQueue.requestSend(0,
        call CXRequestQueue.nextFrame(TRUE), 1,
        FALSE, 0,
        &(pl->timestamp),
        NULL, msg);
    }else{
      printf("PL size error?\r\n");
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
       case 'r':
         post requestLongReceive();
         break;
       case 't':
         post transmit();
         break;
       case 'f':
         post toggleForward();
         break;
       case '?':
         post usage();
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
}
