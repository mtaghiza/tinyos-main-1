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
 * @author Philip Levis
 * @date   Jan 16 2006
 */ 

#include "AM.h"
#include "CXDebug.h"

generic module AMQueueImplP(int numClients) @safe() {
    provides interface Send[uint8_t client];
    uses{
        interface AMSend[am_id_t id];
        interface AMPacket;
        interface Packet;
    }
}

implementation {
    typedef struct {
        message_t* ONE_NOK msg;
        bool sending;
    } queue_entry_t;
  
    queue_entry_t queue[numClients];

    error_t doSend(message_t* msg);
    void sendDone(uint8_t i, message_t* msg, error_t err);
    void retrySends();
    task void retrySendTask();

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
        error_t err;
        if (clientId >= numClients) {
            return FAIL;
        }
        if (queue[clientId].msg != NULL) {
            return EBUSY;
        }
        dbg("AMQueue", "AMQueue: request to send from %hhu (%p): passed checks\n", clientId, msg);
        
        queue[clientId].msg = msg;
        call Packet.setPayloadLength(msg, len);
        
        //try to send regardless of queue state: underlying protocol
        //will either return EALREADY (if it's occupied) or SUCCESS (if
        //it can schedule the transmission)
        dbg("AMQueue", "%s: request to send from %hhu (%p): queue empty\n", __FUNCTION__, clientId, msg);
        
        err = doSend(msg);
        queue[clientId].sending = (err == SUCCESS);

        if (err != SUCCESS && err != EALREADY) {
            dbg("AMQueue", "%s: underlying send failed.\n", __FUNCTION__);
            queue[clientId].msg = NULL;
            queue[clientId].sending = FALSE;
        }

        //Treat retry as success (will have another go when
        //sendDone comes around)
        return (err == EALREADY)? SUCCESS : err;
    }

    //pointer to the client with the last completed SubSend
    uint8_t lastSent = 0;

    event void AMSend.sendDone[am_id_t id](message_t* msg, error_t err) {
      uint8_t i;
      bool found = FALSE;
      for (i=0; i < numClients; i++){
        if (queue[i].msg == msg){
          if (found){
            cwarn(AM, "duplicate msg %p\r\n", msg);
          } 
          found = TRUE;
          //start from the next client when we begin the retries.
          //this should be fair in the sense that the next client
          //using the same underlying transport protocol will get a
          //chance to send before the client which just completed its
          //send gets another go.
          lastSent = i;
          //ERETRY (pre-empted): leave in queue.
          if (err == ERETRY){
            queue[i].sending = FALSE;
          } else {
            //SUCCESS or some other failure: signal up
            sendDone(i, msg, err);
          }
        }
      }
      if (!found){
        cerror(AM, "couldn't find %p in sending\r\n", msg);
      }
      retrySends();
    }

    void sendDone(uint8_t i, message_t * ONE msg, error_t err) {
        queue[i].msg = NULL;
        queue[i].sending = FALSE;
        signal Send.sendDone[i](msg, err);
    }
    
    uint8_t retryCount = 0;
    void retrySends(){
      retryCount = numClients;
      post retrySendTask();
    }

    task void retrySendTask(){
      if (retryCount){
        //advance to next client
        uint8_t i = (lastSent + 1)%numClients;
        //try to send it if there's something pending
        if (queue[i].msg != NULL && !queue[i].sending ){
          error_t error = doSend(queue[i].msg);
          queue[i].sending = (error == SUCCESS);
          if (error != EALREADY && error != SUCCESS){
            //if it fails, let the client know and clean it up.
            sendDone(i, queue[i].msg, error);
          }
        }
        //update state for next retry.
        lastSent = i;
        retryCount --;
        post retrySendTask();
      }
    }

    
    //not supported
    command error_t Send.cancel[uint8_t clientId](message_t* msg) {
      return FAIL;
    }

    error_t doSend(message_t* msg){
      am_id_t nextId = call AMPacket.type(msg);
      am_addr_t nextDest = call AMPacket.destination(msg);
      uint8_t len = call Packet.payloadLength(msg);
      return call AMSend.send[nextId](nextDest, msg, len);
    }
  
    
    command uint8_t Send.maxPayloadLength[uint8_t id]() {
        return call AMSend.maxPayloadLength[0]();
    }

    command void* Send.getPayload[uint8_t id](message_t* m, uint8_t len) {
      return call AMSend.getPayload[0](m, len);
    }

    default event void Send.sendDone[uint8_t id](message_t* msg, error_t err) {
        // Do nothing
    }
    default command error_t AMSend.send[uint8_t id](am_addr_t am_id, message_t* msg, uint8_t len) {
        return FAIL;
    }
}
