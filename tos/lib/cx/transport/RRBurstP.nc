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


 #include "CXTransportDebug.h"
module RRBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface SplitControl;
  //for setup/ack packets
  uses interface Packet;

  uses interface SlotTiming;
  provides interface RequestPending;
  uses interface RoutingTable;
  uses interface AMPacket;
  uses interface CXNetworkPacket;

  uses interface ScheduledAMSend as AckSend;
  uses interface Packet as AckPacket;
  uses interface ActiveMessageAddress;

  uses interface Timer<TMilli> as RetryTimer;
  uses interface StateDump;
  uses interface Receive as AckReceive;
} implementation {
  uint32_t lastTX;
  
  message_t msg_internal;
  message_t* rxMsg = &msg_internal;
  bool rxPending = FALSE;
  bool on = FALSE;
  uint32_t rxf = INVALID_FRAME;
  bool sending;

  bool waitingForAck;
  bool handlingAck;
  message_t* setupMsg;

  message_t ackMsg_internal;
  message_t* ackMsg = &ackMsg_internal;

  uint32_t ackDeadline;

  am_addr_t flowSrc;
  uint16_t flowSn;
  uint32_t ackStart;

  uint8_t retryCount;
  uint8_t lastBw = 0;

  task void receiveNext(){
    if ( on && !rxPending && !handlingAck){
      error_t error; rxf = call CXRequestQueue.nextFrame(FALSE);
      error = call CXRequestQueue.requestReceive(0,
        rxf, 0,
        FALSE, 0,
        0, NULL, rxMsg);
      if (error != SUCCESS){
        if (retryCount < TRANSPORT_RETRY_THRESHOLD){
          cwarn(TRANSPORT, "rrb.rn: %lu %x\r\n", rxf, error);
          call RetryTimer.startOneShot(TRANSPORT_RETRY_TIMEOUT);
        }else{
          cerror(TRANSPORT, "rrb.rn: %lu %x\r\n", rxf, error);
          call StateDump.requestDump();
        }
      }else{
        retryCount = 0;
        rxPending = TRUE;
      }
    }
  }

  event void RetryTimer.fired(){
    retryCount ++;
    post receiveNext();
  }

  task void sendAck(){
    error_t error;
    cx_ack_t* ack = call AckSend.getPayload(ackMsg, 
      sizeof(cx_ack_t));
    call AckPacket.clear(ackMsg);
    ack->distance = call RoutingTable.getDistance(flowSrc,
      call ActiveMessageAddress.amAddress());
    //TODO: should come from schedule, or something.
    ack->bw = RRB_BW;
    ack->sn = flowSn;
    call CXTransportPacket.setSubprotocol(ackMsg, 
      CX_SP_ACK);
    error = call AckSend.send(flowSrc, ackMsg, sizeof(cx_ack_t),
      ackStart);
    cinfo(TRANSPORT, "AS %lu %x\r\n", ackStart, error);
  }
  
  event void AckSend.sendDone(message_t* msg, error_t error){
    cinfo(TRANSPORT, "ASD %x\r\n", error);
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    cdbg(TRANSPORT, "rrb.send %p\r\n", msg);
    if (sending){
      return EALREADY;
    }else{
      uint32_t nf = call CXRequestQueue.nextFrame(TRUE) + RRB_PADDING;
      uint32_t nss = call SlotTiming.nextSlotStart(nf);
      uint32_t txf;
      uint8_t distance = call RoutingTable.getDistance(call ActiveMessageAddress.amAddress(), 
        call AMPacket.destination(msg));
      bool needsSetup = TRUE;
      error_t error;
      
      cinfo(TRANSPORT, "NS %lu %lu %u %lu\r\n", 
        lastTX, 
        call SlotTiming.lastSlotStart(),
        distance,
        call SlotTiming.framesLeftInSlot(nf));
      //not synched yet, try later.
      if (nf == INVALID_FRAME || nss == INVALID_FRAME){
        //TODO: we need a better return code here.
        return FAIL;
      }
      if (lastTX >= call SlotTiming.lastSlotStart()){
        if ( distance < call SlotTiming.framesLeftInSlot(nf)){
          needsSetup = FALSE;
        }
      }
  
      if (needsSetup){
        //TODO: use GetLastBroadcast to figure out whether we need to
        //push this to the next slot or can use this slot. n.b. that
        //this needs to account for the ACK time as well.
        txf = nss;
        cdbg(TRANSPORT, "SP_S: %lu -> %lu\r\n",
          nf, txf);
        call CXTransportPacket.setSubprotocol(msg, CX_SP_SETUP);
        call CXNetworkPacket.setTTL(msg, 
          call RoutingTable.getDefault());
      }else{
        cdbg(TRANSPORT, "SP_D\r\n");
        call CXTransportPacket.setSubprotocol(msg, CX_SP_DATA);
        txf = nf;
        call CXNetworkPacket.setTTL(msg, distance + lastBw);
      }
      call CXTransportPacket.setDistance(msg, distance);
      // - lastTX >= lss? check for whether there's time to finish the
      //   transmission
      //   - TTL = d_sd
      // - no: put SETUP in header
      //   - put in d_ds if available
      //   - enqueue at nss
      //   - TTL = max
      error = call CXRequestQueue.requestSend(0,
        txf, 0,
        TXP_UNICAST,
        FALSE, 0,
        NULL,
        msg);
      if (error == SUCCESS){
        sending = TRUE;
      }
      return error;
    }
  }

  command error_t Send.cancel(message_t* msg){
    //not supported
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  task void handleAck(){
    message_t* msg = rxMsg;
    void* payload = call AckPacket.getPayload(msg, sizeof(cx_ack_t));
    rxMsg = signal AckReceive.receive(msg, payload, sizeof(cx_ack_t));
    handlingAck = FALSE;
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (rxPending){
      rxMsg = msg;
      rxPending = FALSE;

      if (didReceive){
        uint8_t pll = call Packet.payloadLength(msg);
        cdbg(TRANSPORT, "RRB.rh ");
        switch (call CXTransportPacket.getSubprotocol(msg)){
          case CX_SP_SETUP:
            cdbg(TRANSPORT, "s");
            if (call AMPacket.isForMe(msg)){
              flowSrc = call AMPacket.source(msg);
              flowSn = call CXNetworkPacket.getSn(msg);
              ackStart = atFrame + 1;
              post sendAck();
            } else {
              //TODO: could prune now if we are confident in our distance
              //measurements.
            }
            rxMsg = signal Receive.receive(msg,
              call Packet.getPayload(msg, pll), pll);
            break;


          case CX_SP_DATA:
            cdbg(TRANSPORT, "d");
            rxMsg = signal Receive.receive(msg, 
              call Packet.getPayload(msg, pll), 
              pll);
            break;

          case CX_SP_ACK:
            handlingAck = TRUE;
            post handleAck();
            break;
          default:
            cerror(TRANSPORT, "Unrecognized SP %x\r\n",  
              call CXTransportPacket.getSubprotocol(msg));
            break;
        }
        cdbg(TRANSPORT, "\r\n");
      } else {
        //!didReceive
        if (waitingForAck && atFrame > ackDeadline){
          sending = FALSE;
          waitingForAck = FALSE;
          cdbg(TRANSPORT, "#sdNA\r\n");
          signal Send.sendDone(setupMsg, ENOACK);
        }
      }
      post receiveNext();
    } else {
      cerror(TRANSPORT, "!rrb.rh, not rxPending\r\n");
      call StateDump.requestDump();
    }
  }


  event message_t* AckReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    cdbg(TRANSPORT, "a");
    if (waitingForAck){
      cdbg(TRANSPORT, "w %p %p\r\n", msg, setupMsg);
      sending = FALSE;
      waitingForAck = FALSE;
      cdbg(TRANSPORT, "#sdA\r\n");
      signal Send.sendDone(setupMsg, SUCCESS);
    } else {
      cx_ack_t* ack = (cx_ack_t*)payload;
      am_addr_t s = call AMPacket.destination(msg);
      am_addr_t d = call AMPacket.source(msg);
      uint8_t d_si;
      uint8_t d_sd;
      uint8_t d_id;
      bool shouldForward;
      cdbg(TRANSPORT, "W");
      //ack source is flow DEST, ack dest is flow SRC
      //distance in payload is flow SRC to flow DEST
      call RoutingTable.addMeasurement(s, d, ack->distance);
      d_si = call RoutingTable.getDistance(s, call ActiveMessageAddress.amAddress());
      d_sd = call RoutingTable.getDistance(s, d);
      d_id = call RoutingTable.getDistance(call ActiveMessageAddress.amAddress(), d);
      shouldForward = (d_si + d_id <= (d_sd + ack->bw));
      lastBw = ack->bw;
      cinfo(TRANSPORT, "RRB %u %u %u %u %u %u %u %u\r\n",
        s, d, 
        ack->sn,
        d_si,
        d_id,
        d_sd, 
        ack->bw,
        shouldForward);

      if (!shouldForward){
        cdbg(TRANSPORT, "s");
        //sleepy times
        call CXRequestQueue.requestSleep(0,
          call CXRequestQueue.nextFrame(FALSE), 0);
      }else{
        cdbg(TRANSPORT, "S");
        //OK, stay up to help.
      }
    }
    handlingAck = FALSE;
    return msg;
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cdbg(TRANSPORT, "rrb.sh %p %x\r\n", msg,
      call CXTransportPacket.getSubprotocol(msg));
    lastTX = atFrame;
    if (SUCCESS == error){
      switch (call CXTransportPacket.getSubprotocol(msg)){
        case CX_SP_SETUP:
          waitingForAck = TRUE;
          //TODO: could add slack here.
          //use default since ACK will be flooded.
          ackDeadline = (atFrame + 1+ call RoutingTable.getDefault());
          setupMsg = msg;
          cdbg(TRANSPORT, "@%lu wait to %lu\r\n", atFrame,
            ackDeadline);
          break;
        case CX_SP_DATA:
          sending = FALSE;
          cdbg(TRANSPORT, "#sdD\r\n");
          signal Send.sendDone(msg, error);
          break;
        default: 
          //ACK should be going through scheduledSend.
          cerror(TRANSPORT, "Unrecognized SP %x\r\n", 
            call CXTransportPacket.getSubprotocol(msg));
          break;
      }
    } else {
      if (error != ERETRY){
        cerror(TRANSPORT, "rrb.sh: %x\r\n", error);
      }
      sending = FALSE;
      signal Send.sendDone(msg, error);
    }
  }

  event void SplitControl.startDone(error_t error){ 
    if (error == SUCCESS){
      on = TRUE;
      post receiveNext();
    } else {
      cerror(TRANSPORT, "rrb.sc.startDone: %x\r\n", error);
    }
  }

  event void SplitControl.stopDone(error_t error){ 
    if (SUCCESS == error){
      on = FALSE;
    }
  }

  //unused events below
  event void CXRequestQueue.sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){
  }

  command bool RequestPending.requestPending(uint32_t frame){
    return (frame != INVALID_FRAME) && rxPending;
  }
  async event void ActiveMessageAddress.changed(){}

  event void StateDump.dumpRequested(){ }
}
