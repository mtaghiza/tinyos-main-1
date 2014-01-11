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
 * Test CXTDMA logic
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "Rf1a.h"
#include "message.h"
#include "CXTDMA.h"
#include "schedule.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface SplitControl;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
  uses interface TDMARootControl;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;

  uses interface Leds;

} implementation {
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  norace uint8_t tx_len;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  //schedule info
  uint32_t lastFs;
  uint16_t _framesPerSlot;
  
  uint32_t mySn = 0;
  norace bool isRoot = FALSE;

  task void printStatus(){
    printf("----\r\n");
    printf("is root: %x\r\n", isRoot);
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
    }
    call UartControl.start();
    printf("\r\nCXTDMA test\r\n");
    printf("s: start \r\n");
    printf("S: stop \r\n");
    printf("r: root \r\n");
    printf("f: forwarder \r\n");
    printf("?: print status\r\n");
    printf("========================\r\n");
    post printStatus();
  }

  task void setScheduleTask(){
    call TDMARootControl.setSchedule(DEFAULT_TDMA_FRAME_LEN,
        DEFAULT_TDMA_FW_CHECK_LEN, 8, 8, 2, 1);
  }

  event void SplitControl.startDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    if (isRoot){
      post setScheduleTask();
    }
  }

  event void SplitControl.stopDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    if (isRoot){
      if (frameNum == 0){
        return RF1A_OM_FSTXON;
      } else {
        return RF1A_OM_RX;
      }
    } else {
      return RF1A_OM_RX;
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    *msg = tx_msg;
    *len = tx_len;
    return TRUE; 
  }


  //unimplemented
  async event void CXTDMA.frameStarted(uint32_t startTime){ 
    lastFs = startTime;
//    printf("!fs\n\r");
  }

  task void processReceive(){
//    printf("RX %p\r\n", rx_msg);
  }
  
  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum){
    message_t* swp = rx_msg;
    rx_msg = msg;
    rx_len = len;
    post processReceive();
    return swp;
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (SUCCESS != error){
      printf("!sd %x\r\n", error);
    }else{
//      printf("sd\r\n");
    }
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

  task void becomeRoot(){
    isRoot = TRUE;
    post printStatus();
  }

  task void becomeForwarder(){
    isRoot = FALSE;
    post printStatus();
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
      case 'r':
        printf("Become Root\r\n");
        post becomeRoot();
        break;
      case 'f':
        printf("Become Forwarder\r\n");
        post becomeForwarder();
        break;
      case '\r':
        printf("\r\n");
        break;
     default:
        printf("%c", byte);
        break;
    }
  }

  event bool TDMARootControl.isRoot(){
    return isRoot;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames, 
      uint16_t inactiveFrames, uint16_t framesPerSlot, 
      uint16_t maxRetransmit){
//    printf("SR\r\n");
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
