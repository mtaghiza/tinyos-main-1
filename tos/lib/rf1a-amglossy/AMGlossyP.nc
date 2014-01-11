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

#include "AMGlossy.h"
#include "decodeError.h"

generic module AMGlossyP(){
  provides interface AMSend;
  provides interface Receive;
  provides interface AMPacket;

  uses interface AMSend as SubAMSend;
  uses interface AMPacket as SubAMPacket;
  uses interface DelayedSend;
  uses interface SendNotifier;
  uses interface Receive as SubReceive;
  uses interface Rf1aPhysical;
  uses interface Rf1aCoreInterrupt;

  uses interface Alarm<TMicro, uint16_t>;
} implementation {
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;

  enum{
    S_IDLE,
    S_WAIT_RECEIVE,
    S_COPY_TO_TX,
    S_SEND_START,
    S_ORIGIN_SEND_START,
    S_SEND_READY,
    S_ORIGIN_SENDING,
    S_SENDING,
 } ;

 void printMsg(message_t* msg);

 const char* decodeState(uint8_t state_){
   switch(state_){
     case S_IDLE:
       return "S_IDLE";
     case S_WAIT_RECEIVE:
       return "WAIT_RECEIVE";
     case S_COPY_TO_TX:
       return "COPY_TO_TX";
     case S_SEND_START:
       return "SEND_START";
     case S_ORIGIN_SEND_START:
       return "ORIGIN_SEND_START";
     case S_SEND_READY:
       return "SEND_READY";
     case S_ORIGIN_SENDING:
       return "ORIGIN_SENDING";
     case S_SENDING:
       return "SENDING";
     default:
       return "Unknown";
   }
 }
  
  //TODO: atomicity
  uint8_t state = S_IDLE;
  
  uint16_t lastSrc;
  uint16_t lastSn;

  uint16_t mySn;

  task void copyToTX(){
    am_glossy_header_t* header = call SubAMSend.getPayload(tx_msg,
      sizeof(am_glossy_header_t));
    error_t error;
//    printf("Copy from rx (%p) to tx (%p)\n\r", rx_msg, tx_msg);
//    printf("pre copy GSN: %d\n\r", ((am_glossy_header_t*)(call SubAMSend.getPayload(tx_msg,
//      rx_len+sizeof(am_glossy_header_t))))->sn);
//    printf("TX Message %p\n\r", tx_msg);
//    printMsg(tx_msg);
//    printf("RX Message %p\n\r", rx_msg);
//    printMsg(rx_msg);

    //copy from rx to tx, update header
    memcpy(call SubAMSend.getPayload(tx_msg, rx_len), 
      call SubAMSend.getPayload(rx_msg, rx_len),
      rx_len);
    header -> count += 1;
//    printf("post copy GSN: %d\n\r", ((am_glossy_header_t*)(call SubAMSend.getPayload(tx_msg,
//      rx_len+sizeof(am_glossy_header_t))))->sn);
    //check src and sn to suppress duplicates
    //TODO: should be a little more sophisticated than this.
    if (header->src == lastSrc && header->sn == lastSn){
      call Alarm.stop();
//      setSMCLKXT2(FALSE);
      state = S_IDLE;
      printf("Duplicate: %u == %u and %u == %u\n\r", header->src,
        lastSrc, header->sn, lastSn);
//      printf("RX MSG\n\r");
//      printMsg(rx_msg);
//      printf("TX MSG\n\r");
//      printMsg(tx_msg);
      return;
    }
    lastSrc = header->src;
    lastSn = header->sn;

    //signal the original rx up, swap
    //TODO: this should probably be delayed so that the application is
    //  less likely to do something stupid while we're in a
    //  timing-critical period
    rx_msg = signal Receive.receive(rx_msg, call
      AMSend.getPayload(rx_msg, rx_len - sizeof(am_glossy_header_t)), 
      rx_len - sizeof(am_glossy_header_t));
    
    //first half of rebroadcast
    state = S_SEND_START;

    error = call SubAMSend.send(AM_BROADCAST_ADDR, tx_msg, rx_len); 

    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    if (state == S_WAIT_RECEIVE){
      message_t* swp = rx_msg;
//      printf("r\n\r");
//      printf("----\n\r");
//      printf("rx %p (GSN: %d)\n\r", msg,
//        ((am_glossy_header_t*)payload)->sn);
      rx_msg = msg;
      rx_len = len;
      post copyToTX();
      state = S_COPY_TO_TX;
//      printf("return %p\n\r", swp);
      return swp;
    } else {
      printf("%s Ignore receive: busy\n\r", __FUNCTION__);
      return msg;
    }
  }

  async event void DelayedSend.sendReady(){
    if (state == S_ORIGIN_SEND_START){
      state = S_ORIGIN_SENDING;
      call DelayedSend.completeSend();
    } else if (state == S_SEND_START){
      state = S_SEND_READY;
    } else {
      printf("%s: Unexpected sendReady: %s\n\r", __FUNCTION__, decodeState(state));
    }
  }

  async event void Alarm.fired(){
    if (state == S_SEND_READY){
      call DelayedSend.completeSend();
      state = S_SENDING;
    } else if(state == S_WAIT_RECEIVE){
      state = S_IDLE;
//      setSMCLKXT2(FALSE);
      printf("RETX expired before packet received\n\r");
    } else {
//      setSMCLKXT2(FALSE);
      printf("%s: Unexpected alarm: %s \n\r", __FUNCTION__,
        decodeState(state));
    }
  }
  
  async event void Rf1aPhysical.frameStarted () { 
    if (state == S_IDLE){
//      setSMCLKXT2(TRUE);
      call Alarm.start(RETX_DELAY);
      state = S_WAIT_RECEIVE;
    } else if (state == S_ORIGIN_SENDING || state == S_SENDING){
      //ok, we got this because we were transmitting. 
      call Alarm.stop();
//      setSMCLKXT2(FALSE);
//      printf("TX Frame start (cancel)\n\r");
    } else {
      call Alarm.stop();
//      setSMCLKXT2(FALSE);
      printf("Unexpected Frame start: %s\n\r", decodeState(state));
    }
  }

  //include length of glossy header
  command void* AMSend.getPayload(message_t* msg, uint8_t len){
    return (call SubAMSend.getPayload(msg, len + sizeof(am_glossy_header_t))) 
      + sizeof(am_glossy_header_t);
  }

  command error_t AMSend.send(am_addr_t addr, message_t* msg, 
      uint8_t len){
    if (state != S_IDLE){
      return EBUSY;
    } else {
      error_t error;
      am_glossy_header_t* hdr = call SubAMSend.getPayload(msg, len +
        sizeof(am_glossy_header_t));
      hdr->src = call SubAMPacket.address();
      hdr->dest = addr;
      hdr->sn = mySn++;
      state = S_ORIGIN_SEND_START;
      error = call SubAMSend.send(AM_BROADCAST_ADDR, msg, len +
        sizeof(am_glossy_header_t)); 
      lastSrc = hdr->src;
      lastSn = hdr->sn;
      if (error != SUCCESS){
        printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
      }
      return error;
    }
  }

  event void SubAMSend.sendDone(message_t* msg, error_t error){
    if (state == S_ORIGIN_SENDING){
      signal AMSend.sendDone(msg, error);
    }else{
      //done forwarding
    }
    state = S_IDLE;
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }

  command uint8_t AMSend.maxPayloadLength(){
    return call SubAMSend.maxPayloadLength() - sizeof(am_glossy_header_t);
  }

  command error_t AMSend.cancel(message_t* msg){
    //TODO: how to handle?
    return FAIL;
  }

  command am_addr_t AMPacket.address(){
    return call SubAMPacket.address();
  }

  command am_addr_t AMPacket.source(message_t* amsg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> src;
  }

  command void AMPacket.setSource(message_t* amsg, am_addr_t addr){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> src = addr;
  }
  
  command am_addr_t AMPacket.destination(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> dest;
  }
  
  command void AMPacket.setDestination(message_t* msg, am_addr_t addr){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> dest = addr;
  }

  command am_group_t AMPacket.group(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> group;
  }

  command void AMPacket.setGroup(message_t* amsg, am_group_t grp){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> group = grp;
  }

  command am_group_t AMPacket.localGroup(){
    return call SubAMPacket.localGroup();
  }

  command am_id_t AMPacket.type(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> type;
  }

  command void AMPacket.setType(message_t* msg, am_id_t t){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> type = t;
  }

  command bool AMPacket.isForMe(message_t* amsg){
    am_addr_t dest = call AMPacket.destination(amsg);
    am_group_t grp = call AMPacket.group(amsg);
    return (grp == call AMPacket.localGroup() && 
      (dest == call AMPacket.address() || dest == AM_BROADCAST_ADDR));
  }

  void printMsg(message_t* msg){
    uint8_t i;
    am_glossy_header_t* hdr = (am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)));
    printf("AM SRC: %x\n\r", call SubAMPacket.source(msg));
    printf("G SRC: %x\n\r", call AMPacket.source(msg));
    printf("G SN: %d", hdr->sn);

//    for(i = 0; i < sizeof(message_t); i++){
    for(i = 0; i < 64; i++){
      if ((i % 4)==0){
        printf("\n\r[%d]",i);
      }
      printf("\t%x", ((uint8_t*)msg)[i]);
    }
    printf("\n\r");
  }

  event void SendNotifier.aboutToSend(am_addr_t addr, message_t* msg){
    call SubAMPacket.setSource(msg, call AMPacket.source(msg));
//    printMsg(msg); 
  }

  async event void Rf1aPhysical.receiveStarted (unsigned int length) { 
//    printf("RX start %d\n\r", length);
  }

  async event void Rf1aPhysical.clearChannel () { 
//    printf("cc\n\r");
  }
  async event void Rf1aPhysical.carrierSense () { 
//    printf("cs\n\r");
  }

  //Use this if configurable GDO signals desired (See
  //  HplMsp430Rf1aP.configure: interrupts are hard-coded. Probably
  //  just need the frame-start interrupt)
  async event void Rf1aCoreInterrupt.interrupt(uint16_t iv){ }

  //unused events
  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
    unsigned int count, int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
    unsigned int count) { }
  async event void Rf1aPhysical.released () { }

  
}
