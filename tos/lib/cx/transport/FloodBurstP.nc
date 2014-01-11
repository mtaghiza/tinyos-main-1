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
module FloodBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface Packet;
  uses interface SplitControl;
  uses interface CXPacketMetadata;
  uses interface SlotTiming;
  uses interface AMPacket;
  provides interface RequestPending;
  uses interface RoutingTable;

  uses interface Get<uint32_t> as GetLastBroadcast;

  uses interface ActiveMessageAddress;
  uses interface Timer<TMilli> as RetryTimer;
  uses interface StateDump;
} implementation {
  message_t msg_internal;
  //We only own this buffer when there is no rx pending. We have no
  //guarantee that we'll get the same buffer back when the receive is
  //handled.
  message_t* rxMsg = &msg_internal;
  bool sending = FALSE;
  bool rxPending = FALSE;
  bool on = FALSE;
  uint32_t rxf = INVALID_FRAME;

  uint8_t retryCount;

  task void receiveNext(){
    if ( on && !rxPending){
      error_t error;
      rxf = call CXRequestQueue.nextFrame(FALSE);
      error = call CXRequestQueue.requestReceive(0,
        rxf, 0,
        FALSE, 0,
        0, NULL, rxMsg);
      if (error != SUCCESS){
        if (retryCount < TRANSPORT_RETRY_THRESHOLD){
          cwarn(TRANSPORT, "fb.rn: %lu %x\r\n", 
            rxf, error);
          call RetryTimer.startOneShot(TRANSPORT_RETRY_TIMEOUT);
        }else{
          cerror(TRANSPORT, "fb.rn: %lu %x\r\n", 
            rxf, error);
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

  event void SplitControl.startDone(error_t error){
    if (error == SUCCESS){
      on = TRUE;
      post receiveNext();
    } else {
      cerror(TRANSPORT, "!fb.sc.startDone: %x\r\n", error);
      call StateDump.requestDump();
    }
  }

  event void SplitControl.stopDone(error_t error){
    if (SUCCESS == error){
      on = FALSE;
    }
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    cdbg(TRANSPORT, "FB.send\r\n");
    if (! sending){
      uint32_t nf = call CXRequestQueue.nextFrame(TRUE);
      if (nf != INVALID_FRAME && call SlotTiming.framesLeftInSlot(nf) >= 
          call RoutingTable.getDistance(call ActiveMessageAddress.amAddress(), 
            call AMPacket.destination(msg))){
        //Cool, there's enough frames left in this slot.
        uint32_t lss = call SlotTiming.lastSlotStart();

        if (nf == lss || call GetLastBroadcast.get() >= lss){
          cdbg(TRANSPORT, "FB #\r\n");
          //cool, the network is set up for receiving broadcasts (this
          //is either the first frame of the slot, or we've previously
          //sent a broadcast during this slot).
        } else {
          cdbg(TRANSPORT, "FB->\r\n");
          nf = call SlotTiming.nextSlotStart(nf); 
        }
      } else {
        cdbg(TRANSPORT, "FB->\r\n");
        nf = call SlotTiming.nextSlotStart(nf);
      }

      //  this slot to deliver it.
      if (nf != INVALID_FRAME){
        //TODO: should set TTL here? (based on RoutingTable.distance)
        error_t error;
        call CXTransportPacket.setSubprotocol(msg, CX_SP_DATA);
        error = call CXRequestQueue.requestSend(0,
          nf, 0,
          TXP_BROADCAST,
          FALSE, 0,
          NULL, 
          msg);
        if (error == SUCCESS){
          sending = TRUE;
        }
        return error;
      }else{
        return FAIL;
      }

    } else { 
      return EALREADY;
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
        rxMsg = signal Receive.receive(msg, 
          call Packet.getPayload(msg, pll),
          pll);
      }
      post receiveNext();
    } else {
      cerror(TRANSPORT, "fb.rh, not rxPending\r\n");
      call StateDump.requestDump();
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    sending = FALSE;
    cdbg(TRANSPORT, "fb.sd %p %x\r\n", msg, error);
    signal Send.sendDone(msg, error);
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

  event void StateDump.dumpRequested(){}
}
