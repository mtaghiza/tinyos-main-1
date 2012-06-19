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

generic module CXAMQueueImplP(int numClients) @safe() {
    provides interface Send[uint8_t client];
    uses interface AMSend as UnreliableBurstSend[am_id_t id];
    uses interface AMSend as SimpleFloodSend[am_id_t id];
    uses interface AMPacket;
    uses interface Packet;
    uses interface CXPacket;
    uses interface SlotStarted;
    uses interface TDMARoutingSchedule;
    uses interface ScheduledSend[uint8_t client];
}

implementation {
    uint16_t curSlot = INVALID_SLOT;
    uint16_t nextSlot = INVALID_SLOT;
    uint8_t nextClient = numClients;

    bool isSending = FALSE;

    typedef struct {
        message_t* ONE_NOK msg;
        uint16_t sendSlot;
    } queue_entry_t;
  
    queue_entry_t queue[numClients];
    uint8_t cancelMask[numClients/8 + 1];

    task void doSend();
  
    task void nextPacket() {
      printf_TMP("%s: \r\n", __FUNCTION__);
      //this is where the scheduled-send logic comes in:
      //iterate through clients, check for next claimed slot 
      if (!isSending){
        uint8_t i;
        uint16_t closestSend = 0xffff;
        for(i=nextClient; i < numClients; i++){
          uint8_t k = (nextClient+i)%numClients;
          if (queue[k].msg != NULL && !(cancelMask[k/8] & (1 << k%8))){
            uint16_t slotsRemaining;
            if (curSlot <= queue[k].sendSlot){
              slotsRemaining = queue[k].sendSlot - curSlot;
            }else{
              slotsRemaining = (queue[k].sendSlot + call TDMARoutingSchedule.getNumSlots()) - curSlot;
            }
            if (slotsRemaining < closestSend){
              closestSend = slotsRemaining;
              nextSlot = queue[k].sendSlot;
              nextClient = k;
            }
          }
        }
        if (closestSend == 0){
          post doSend();
        }
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
        printf_TMP("%s: \r\n", __FUNCTION__);
        if (clientId >= numClients) {
            return FAIL;
        }
        if (queue[clientId].msg != NULL) {
            return EBUSY;
        }
        dbg("AMQueue", "AMQueue: request to send from %hhu (%p): passed checks\n", clientId, msg);
        
        queue[clientId].msg = msg;
        queue[clientId].sendSlot = call ScheduledSend.getSlot[clientId]();
        call Packet.setPayloadLength(msg, len);

        post nextPacket();
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
            am_id_t amId = call AMPacket.type(msg);
            uint8_t tProtoId = call CXPacket.getTransportProtocol(msg);
            error_t err;
            switch(tProtoId){
              case CX_TP_UNRELIABLE_BURST:
                err = call UnreliableBurstSend.cancel[amId](msg);
                break;

              case CX_TP_SIMPLE_FLOOD:
                err = call SimpleFloodSend.cancel[amId](msg);
                break;

              default:
                err = FAIL;
                break;
            }
            return err;
        }
        else {
            cancelMask[clientId/8] |= 1 << clientId % 8;
            post CancelTask();
            return SUCCESS;
        }
    }

    void sendDone(uint8_t last, message_t * ONE msg, error_t err) {
        queue[last].msg = NULL;
        post nextPacket();
        signal Send.sendDone[last](msg, err);
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
    }


    event void SlotStarted.slotStarted(uint16_t slotNum){
      printf_TMP("%s: %u\r\n", __FUNCTION__, slotNum);
      curSlot = slotNum;
      if (INVALID_SLOT != curSlot && nextSlot == curSlot){
        post doSend();
      }
    }

    task void doSend(){
      error_t nextErr;
      message_t* nextMsg = queue[nextClient].msg;
      am_id_t nextId = call AMPacket.type(nextMsg);
      am_addr_t nextDest = call AMPacket.destination(nextMsg);
      uint8_t len = call Packet.payloadLength(nextMsg);

      printf_TMP("%s: \r\n", __FUNCTION__);

      //TODO: should find out whether it is deliverable or not
      //  before passing down to transport!
      switch(call CXPacket.getTransportProtocol(nextMsg)){
        case CX_TP_UNRELIABLE_BURST:
          nextErr = call UnreliableBurstSend.send[nextId](nextDest, nextMsg, len);
          break;
        case CX_TP_SIMPLE_FLOOD:
          nextErr = call SimpleFloodSend.send[nextId](nextDest, nextMsg, len);
          break;
        default:
          nextErr = FAIL;
          break;
      }
      if(nextErr != SUCCESS) {
          post errorTask();
      }else{
        isSending = TRUE;
      }
    }
    
    event void UnreliableBurstSend.sendDone[am_id_t id](message_t* msg, error_t err) {
      sendDoneEvent(msg, err);
    }
    event void SimpleFloodSend.sendDone[am_id_t id](message_t* msg, error_t err) {
      sendDoneEvent(msg, err);
    }
    
    command uint8_t Send.maxPayloadLength[uint8_t id]() {
        return call SimpleFloodSend.maxPayloadLength[0]();
    }

    command void* Send.getPayload[uint8_t id](message_t* m, uint8_t len) {
        return call SimpleFloodSend.getPayload[0](m, len);
    }
    default event void Send.sendDone[uint8_t id](message_t* msg, error_t err) {
        // Do nothing
    }

    default command error_t UnreliableBurstSend.send[uint8_t id](am_addr_t am_id, message_t* msg, uint8_t len) {
        return FAIL;
    }

    default command error_t SimpleFloodSend.send[uint8_t id](am_addr_t am_id, message_t* msg, uint8_t len) {
        return FAIL;
    }

    default command uint16_t ScheduledSend.getSlot[uint8_t clientId](){
      return call TDMARoutingSchedule.getDefaultSlot();
    }
}
