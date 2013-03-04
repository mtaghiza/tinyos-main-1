// $Id: AMQueueImplP.nc,v 1.11 2010-06-29 22:07:56 scipio Exp $
/*
* Copyright (c) 2005 Stanford University. All rights reserved.
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
 * An AM send queue that provides a Service Instance pattern for
 * formatted packets and calls an underlying AMSend in a round-robin
 * fashion. Used to share L2 bandwidth between different communication
 * clients.
 *
 * extended with scheduled-send and differentiate between CX transport
 * protocols
 *
 * @author Philip Levis
 * @author Doug Carlson
 * @date   Jan 16 2006
 */ 

#include "AM.h"
#include "schedule.h"
#include "decodeError.h"

#ifndef printf_APP 
#define printf_APP(...) 
#endif
#ifndef printf_TMP 
#define printf_TMP(...) 
#endif

generic module CXAMQueueImplP(int numClients) @safe() {
    provides interface Send[uint8_t client];
    uses interface Send as SubSend[uint8_t tproto];
    uses interface AMPacket;
    uses interface Packet as AMPacketBody;
    uses interface CXPacket;
    uses interface SlotStarted;
    uses interface TDMARoutingSchedule;
    uses interface ScheduledSend[uint8_t client];
    uses interface ScheduledSend as DefaultScheduledSend;
}

implementation {
    uint16_t curSlot = INVALID_SLOT;
    uint16_t nextSlot = INVALID_SLOT;
    uint8_t nextClient = numClients;

    bool isSending = FALSE;
    bool someDeferred = FALSE;

    typedef struct {
        message_t* ONE_NOK msg;
        uint16_t sendSlot;
        bool deferred;
    } queue_entry_t;
  
    queue_entry_t queue[numClients];
    uint8_t cancelMask[numClients/8 + 1];

    task void doSendTask();
    void doSend();
  
    task void nextPacketTask() {
      bool validSender = FALSE;
      if (curSlot == INVALID_SLOT){
        curSlot = call SlotStarted.currentSlot();
      }

      //this is where the scheduled-send logic comes in:
      //iterate through clients, check for next claimed slot 
      if (!isSending && curSlot != INVALID_SLOT){
        uint8_t i;
        uint16_t closestSend = 0xffff;
//        printf_TMP("NP curSlot: %u\r\n", curSlot);
//        printf_TMP("not sending\r\n");
        //start with next client and loop around
        for(i = 1; i < numClients+1; i++){
          uint8_t k = (nextClient+i)%numClients;
          if (!queue[k].deferred && queue[k].msg != NULL && !(cancelMask[k/8] & (1 << k%8))){
            uint16_t slotsRemaining;
            validSender = TRUE;
//            printf_TMP("check c %u s %u: ", k,
//              queue[k].sendSlot);
            if (curSlot <= queue[k].sendSlot){
              slotsRemaining = queue[k].sendSlot - curSlot;
            }else{
              slotsRemaining = (queue[k].sendSlot + call TDMARoutingSchedule.getNumSlots()) - curSlot;
            }
            if (slotsRemaining < closestSend){
//              printf_TMP("keep %u < %u\r\n", slotsRemaining,
//                closestSend);
//              printf_TMP("%u is closer than %u\r\n", slotsRemaining,
//                closestSend);
              closestSend = slotsRemaining;
              nextSlot = queue[k].sendSlot;
              nextClient = k;
            }else{
//              printf_TMP("skip %u !< %u\r\n", slotsRemaining,
//                closestSend);
//              printf_TMP("%u is not closest\r\n", slotsRemaining);
            }
          }else{
//            printf_TMP("client %u not pending\r\n", k);
          }
        }
        if (closestSend == 0 && validSender){
//          printf_TMP("send now\r\n");
          doSend();
        }
      }
      if (! validSender){
        nextSlot = INVALID_SLOT;
      }
    }

    /**
     * Accepts a properly formatted AM packet for later sending.
     * Assumes that someone has filled in the AM packet fields
     * (destination, AM type).
     *
     * @param msg - the message to send
     * @param len - the length of the payload
     *
     */
    command error_t Send.send[uint8_t clientId](message_t* msg,
                                                uint8_t len) {
        if (clientId >= numClients) {
            return FAIL;
        }
        if (queue[clientId].msg != NULL) {
            printf("busy: q@ %u\r\n", queue[clientId].sendSlot);
            return EBUSY;
        }
        dbg("AMQueue", "AMQueue: request to send from %hhu (%p): passed checks\n", clientId, msg);
        
        queue[clientId].msg = msg;
        queue[clientId].sendSlot = call ScheduledSend.getSlot[clientId]();
        queue[clientId].deferred = FALSE;
//        printf_TMP("AMQ: client %u @ %u\r\n", clientId,
//          queue[clientId].sendSlot);
        post nextPacketTask();
        return SUCCESS;
    }

    task void CancelTask() {
        uint8_t i,j,mask,last;
        message_t *msg;
        for(i = 0; i < numClients/8 + 1; i++) {
            if(cancelMask[i]) {
                for(mask = 1, j = 0; j < 8; j++) {
                    if(cancelMask[i] & mask) {
                        last = i*8 + j;
                        msg = queue[last].msg;
                        queue[last].msg = NULL;
                        if (queue[last].sendSlot == nextSlot){
                          post nextPacketTask();
                        }
                        queue[last].sendSlot = INVALID_SLOT;
                        queue[last].deferred = FALSE;
                        cancelMask[i] &= ~mask;
                        signal Send.sendDone[last](msg, ECANCEL);
                    }
                    mask <<= 1;
                }
            }
        }
    }
    
    command error_t Send.cancel[uint8_t clientId](message_t* msg) {
        if (clientId >= numClients ||         // Not a valid client    
            queue[clientId].msg == NULL ||    // No packet pending
            queue[clientId].msg != msg) {     // Not the right packet
            return FAIL;
        }
        if(isSending && (nextClient == clientId)) {
            uint8_t tProtoId = call CXPacket.getTransportProtocol(msg);
            return call SubSend.cancel[tProtoId](msg);
        }
        else {
            cancelMask[clientId/8] |= 1 << clientId % 8;
            post CancelTask();
            return SUCCESS;
        }
    }

    void sendDone(uint8_t last, message_t * ONE msg, error_t err) {
      if (err == ERETRY){
        queue[last].deferred = TRUE;
        someDeferred = TRUE;
        nextSlot = INVALID_SLOT;
        post nextPacketTask();
      }else{
        queue[last].msg = NULL;
        nextSlot = INVALID_SLOT;
        post nextPacketTask();
        printf_APP("TX s: %u d: %u sn: %u ofn: %u np: %u pr: %u tp: %u am: %u e: %u\r\n",
          TOS_NODE_ID,
          call CXPacket.destination(msg),
          call CXPacket.sn(msg),
          call CXPacket.getOriginalFrameNum(msg),
          (call CXPacket.getNetworkProtocol(msg)) & ~CX_NP_PREROUTED,
          ((call CXPacket.getNetworkProtocol(msg)) & CX_NP_PREROUTED)?1:0,
          call CXPacket.getTransportProtocol(msg),
          call AMPacket.type(msg),
          err);
        signal Send.sendDone[last](msg, err);
      }
    }

    task void errorTask() {
        sendDone(nextClient, queue[nextClient].msg, FAIL);
    }

//    // NOTE: Increments current!
//    void tryToSend() {
//        nextPacket();
//        if (current < numClients) { // queue not empty
//        }
//    }

    void sendDoneEvent(message_t* msg, error_t err){
      isSending = FALSE;
      // Bug fix from John Regehr: if the underlying radio mixes things
      // up, we don't want to read memory incorrectly. This can occur
      // on the mica2.
      // Note that since all AM packets go through this queue, this
      // means that the radio has a problem. -pal
      if (nextClient >= numClients) {
          return;
      }
      if(queue[nextClient].msg == msg) {
          sendDone(nextClient, msg, err);
      }
      else {
          dbg("PointerBug", "%s received send done for %p, signaling for %p.\n",
              __FUNCTION__, msg, queue[current].msg);
      }
      post nextPacketTask();
    }


    event void SlotStarted.slotStarted(uint16_t slotNum){
      uint16_t previousSlot = curSlot;
      curSlot = slotNum;
//      printf_TMP("%s: %u (%u)\r\n", __FUNCTION__, slotNum, nextSlot);
      if (someDeferred){
        uint8_t i;
        someDeferred = FALSE;
        for (i=0; i< numClients; i++){
          queue[i].deferred = FALSE;
        }
        post nextPacketTask();
      }

      //corner case: if this is the first valid slot we've detected,
      //then we should check for the next scheduled packet
      if (previousSlot == INVALID_SLOT){
        post nextPacketTask();
      }else if (nextSlot == curSlot && ! isSending){
//        printf_TMP("a%u\r\n", slotNum);
        doSend();
      }
    }

    task void doSendTask(){
      doSend();
    }

    void doSend(){
      error_t nextErr = ERETRY;

      //If we're not synched, defer initiating new transmissions.
      if (call ScheduledSend.sendReady[nextClient]()){
        message_t* nextMsg = queue[nextClient].msg;
        uint8_t len = call AMPacketBody.payloadLength(nextMsg);
  
//      printf_TMP("%s: \r\n", __FUNCTION__);
//        printf_TMP("send for tp %x client %u @ %u\r\n", 
//          call CXPacket.getTransportProtocol(nextMsg), nextClient, curSlot);
        nextErr = call SubSend.send[call CXPacket.getTransportProtocol(nextMsg)](nextMsg, len);
        if (nextErr != SUCCESS && nextErr != ERETRY){
          printf_TMP("tp %x client %u slot %u pkt %p\r\n",
            call CXPacket.getTransportProtocol(nextMsg), nextClient,
              curSlot, nextMsg);
        }
      }

      if (nextErr == ERETRY){
          //defer for now: nextPacket will skip any deferred clients
          //deferred flags cleared at slot boundary.
//          printf_TMP("deferred.\r\n");
          queue[nextClient].deferred = TRUE;
          someDeferred = TRUE;
          nextSlot = INVALID_SLOT;
          post nextPacketTask();
      } else if(nextErr != SUCCESS) {
        printf("%s: %s\r\n", __FUNCTION__, decodeError(nextErr));

        post errorTask();
      } else {
//        printf_TMP("sending.\r\n");
        isSending = TRUE;
      }
    }
    
    event void SubSend.sendDone[uint8_t tProto](message_t* msg, error_t err) {
//      printf("%s: @ %u\r\n", __FUNCTION__, curSlot);
      sendDoneEvent(msg, err);
    }

    command uint8_t Send.maxPayloadLength[uint8_t id]() {
        return call AMPacketBody.maxPayloadLength();
    }

    command void* Send.getPayload[uint8_t id](message_t* m, uint8_t len) {
        return call AMPacketBody.getPayload(m, len);
    }

    default event void Send.sendDone[uint8_t id](message_t* msg, error_t err) {
        // Do nothing
    }

    default command error_t SubSend.send[uint8_t tProto](message_t* msg, uint8_t len) {
        return FAIL;
    }
    default command error_t SubSend.cancel[uint8_t tProto](message_t* msg) {
        return FAIL;
    }

    default command uint16_t ScheduledSend.getSlot[uint8_t clientId](){
      return call DefaultScheduledSend.getSlot();
    }
    default command bool ScheduledSend.sendReady[uint8_t clientId](){
      return call DefaultScheduledSend.sendReady();
    }
}
