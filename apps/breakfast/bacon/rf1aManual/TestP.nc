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
 * Stepping through low-level radio operations manually to ensure that
 * TDMA component will work as planned.
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "Rf1a.h"
#include "message.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aStatus;

  uses interface Rf1aPacket;
  uses interface AMPacket;
  uses interface Ieee154Packet;

} implementation {
  bool nextStateRx = TRUE;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;

  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;

  const char* decodeStatus(){
    switch(call Rf1aStatus.get()){
      case RF1A_S_IDLE:
        return "S_IDLE";
      case RF1A_S_RX:
        return "S_RX";
      case RF1A_S_TX:
        return "S_TX";
      case RF1A_S_FSTXON:
        return "S_FSTXON";
      case RF1A_S_CALIBRATE:
        return "S_CALIBRATE";
      case RF1A_S_FIFOMASK:
        return "S_FIFOMASK";
      case RF1A_S_SETTLING:
        return "S_SETTLING";
      case RF1A_S_RXFIFO_OVERFLOW:
        return "S_RXFIFO_OVERFLOW";
      case RF1A_S_TXFIFO_UNDERFLOW:
        return "S_TXFIFO_UNDERFLOW";
      case RF1A_S_OFFLINE:
        return "S_OFFLINE";
      default:
        return "???";
    }
  }

  task void printStatus(){
    printf("* Core Status: %s\n\r", decodeStatus());
    printf("* next state RX? %x\n\r", nextStateRx);
    printf("--------\n\r");
  }

  event void Boot.booted(){
    //timing pins
    P1SEL &= ~(BIT1|BIT3|BIT4);
    P1SEL |= BIT2;
    P1DIR |= (BIT1|BIT2|BIT3|BIT4);
    P2SEL &= ~(BIT4);
    P2DIR |= (BIT4);
    //set up SFD GDO on 1.2
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
    }

    call UartControl.start();
    printf("\n\rManual RF1A test\n\r");
    printf("s: start (request resource)\n\r");
    printf("S: stop (release resource)\n\r");
    printf("r: receive (startReception/setRxBuffer)\n\r");
    printf("R: cancel receive (go back to idle) \n\r");
    printf("f: FSTXON (startTransmit)\n\r");
    printf("t: TX (completeTransmit)\n\r");
    printf("n: toggle next state RX\n\r");
    printf("i: resume idle mode\n\r");
    printf("?: print status\n\r");
    printf("========================\n\r");
    post printStatus();
  }


  task void startTask(){
    error_t error = call Resource.request();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
  }

  task void stopTask(){
    error_t error = call Resource.release();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
    post printStatus();
  }

  task void startReceiveTask(){
    error_t error;
    error = call Rf1aPhysical.setReceiveBuffer(
      (uint8_t*)(rx_msg->header),
      TOSH_DATA_LENGTH + sizeof(message_header_t),
      (nextStateRx ? RF1A_OM_RX : RF1A_OM_FSTXON));
//    //not necessary: setReceiveBuffer switches us into RX mode
//    // already.
//    if (error == SUCCESS){
//      error = call Rf1aPhysical.startReception();
//    }
    printf("%s: done: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  task void cancelReceiveTask(){
    error_t error = call Rf1aPhysical.setReceiveBuffer(0, 0,
      nextStateRx? RF1A_OM_RX: RF1A_OM_FSTXON);
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  task void startTransmitTask(){
    error_t error = call Rf1aPhysical.startSend(FALSE,
      nextStateRx? RF1A_OM_RX: RF1A_OM_FSTXON);
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  task void completeTransmitTask(){
    error_t error;
    call Rf1aPacket.configureAsData(tx_msg);
    call AMPacket.setSource(tx_msg, call AMPacket.address());
    call Ieee154Packet.setPan(tx_msg, call Ieee154Packet.localPan());
    call AMPacket.setDestination(tx_msg, AM_BROADCAST_ADDR);
    call AMPacket.setType(tx_msg, 0xdc);    
    error = call Rf1aPhysical.completeSend((uint8_t*)tx_msg, sizeof(message_header_t) +
      sizeof(rf1a_nalp_am_t));
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  task void toggleNextStateRXTask(){
    nextStateRx = !nextStateRx;
    post printStatus();
  }

  task void resumeIdleTask(){
    error_t error;
    error = call Rf1aPhysical.resumeIdleMode();
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 's':
        printf("Starting\n\r");
        post startTask();
        break;
      case 'S':
        printf("Stopping\n\r");
        post stopTask();
        break;
      case 'r':
        printf("Start receive\n\r");
        post startReceiveTask();
        break;
      case 'R':
        printf("Cancel receive\n\r");
        post cancelReceiveTask();
        break;
      case 'f':
        printf("Start Transmit\n\r");
        post startTransmitTask();
        break;
      case 't':
        printf("Complete Transmit\n\r");
        post completeTransmitTask();
        break;
      case 'n':
        printf("Toggle next state RX\n\r");
        post toggleNextStateRXTask();
        break;
      case '?':
        post printStatus();
        break;
      case 'i':
        printf("Resume idle\n\r");
        post resumeIdleTask();
        break;
      case '\r':
        printf("\n\r");
        break;
     default:
        printf("%c", byte);
        break;
    }
  }

  event void Resource.granted(){
    printf("%s: \n\r", __FUNCTION__);  
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call HplMsp430Rf1aIf.writeSinglePATable(0x25);

    post printStatus();
  }

  async event void Rf1aPhysical.frameStarted () { 
    printf("!fs\n\r");
  }

  async event void Rf1aPhysical.carrierSense () { 
    printf("!cs\n\r");
  }

  task void reportRX(){
    error_t error;
    printf("RX from %x\n\r", call AMPacket.source(rx_msg));
    error = call Rf1aPhysical.setReceiveBuffer(
      (uint8_t*)(rx_msg->header),
      TOSH_DATA_LENGTH + sizeof(message_header_t),
      (nextStateRx ? RF1A_OM_RX : RF1A_OM_FSTXON));
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    post reportRX();
    printf("!rd\n\r");
  }

  async event void Rf1aPhysical.sendDone (int result) { 
    printf("!sd\n\r");
  }

  //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }

  async event bool Rf1aPhysical.idleModeRx () { 
    return FALSE;
  }

}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
