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


 #include "CXTransport.h"
 #include "CXScheduler.h"
 #include "CXTransportDebug.h"
module CXTransportDispatchP {
  provides interface CXRequestQueue[uint8_t tp];
  uses interface CXRequestQueue as SubCXRQ;

  provides interface SplitControl;
  provides interface SplitControl as SubProtocolSplitControl[uint8_t tp];
  uses interface SplitControl as SubSplitControl;

  uses interface CXTransportPacket;
  uses interface CXPacketMetadata;

  uses interface RequestPending[uint8_t tp];
  
  //ugh. for destination
  uses interface AMPacket;

  provides interface Get<uint32_t> as GetLastBroadcast;
} implementation {
  
  //used for coordination between FB, RRB, and ScheduledSend to
  //determine when the network is awake.
  uint32_t lastBC;

  //splitcontrol:
  // - commands and events should be passed through
  // - at SubSplitControl.startDone, notify CXRequestQueue clients
  //   that we're up 

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }
  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    signal SubProtocolSplitControl.startDone[CX_TP_FLOOD_BURST](error);
    signal SubProtocolSplitControl.startDone[CX_TP_RR_BURST](error);
    
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SubProtocolSplitControl.stopDone[CX_TP_FLOOD_BURST](error);
    signal SubProtocolSplitControl.stopDone[CX_TP_RR_BURST](error);
    signal SplitControl.stopDone(error);
  }

  //CXRequestQueue: 
  // - pass them on down
  
  command uint32_t CXRequestQueue.nextFrame[uint8_t tp](bool isTX){
    return call SubCXRQ.nextFrame(isTX);
  }

  command error_t CXRequestQueue.requestReceive[uint8_t tp](uint8_t layerCount,
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call SubCXRQ.requestReceive(layerCount, baseFrame, frameOffset,
      useMicro, microRef, duration, md, msg);
  }

  command error_t CXRequestQueue.requestSend[uint8_t tp](
      uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    cdbg(TRANSPORT, "rs %p from %x\r\n", msg, tp);
    call CXTransportPacket.setProtocol(msg, tp);
    return call SubCXRQ.requestSend(layerCount, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  command error_t CXRequestQueue.requestSleep[uint8_t tp](uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount, baseFrame,
      frameOffset);
  }

  command error_t CXRequestQueue.requestWakeup[uint8_t tp](uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset,
      uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call SubCXRQ.requestWakeup(layerCount, baseFrame,
      frameOffset, refFrame, refTime, correction);
  }
  
  uint32_t lastRXFrame = INVALID_FRAME;
  uint8_t nextRX = CX_TP_FLOOD_BURST;

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    uint8_t signalTp; 
    if (didReceive){
      if (lastRXFrame == atFrame){
        cerror(TRANSPORT, "RX twice in same frame\r\n");
        return;
      }
      lastRXFrame = atFrame;
      signalTp = call CXTransportPacket.getProtocol(msg);

      if (signalTp == CX_TP_SCHEDULED){
        cdbg(TRANSPORT, "rx tps ");
        if (call AMPacket.destination(msg) == AM_BROADCAST_ADDR){
          cdbg(TRANSPORT, "bcast\r\n");
          signalTp = CX_TP_FLOOD_BURST;
        } else {
          cdbg(TRANSPORT, "ucast\r\n");
          signalTp = CX_TP_RR_BURST;
        }
      }

      if (! call RequestPending.requestPending[signalTp](reqFrame)){
        cwarn(TRANSPORT, "no pending rx to %x, drop\r\n", signalTp);
        didReceive = FALSE;
      }
    } 

    if (!didReceive){
      uint8_t i;
      signalTp = nextRX;
      for (i = 0; i < NUM_RX_TRANSPORT_PROTOCOLS; i++){
        if (! call RequestPending.requestPending[signalTp](reqFrame)){
          signalTp = (1+signalTp)%NUM_RX_TRANSPORT_PROTOCOLS;
        } else {
          break;
        }
      }
    }

    if (didReceive){
      cdbg(TRANSPORT, "rxh to %x %x (%x)\r\n", 
        call CXTransportPacket.getProtocol(msg), 
        signalTp, nextRX);
    }

    if (call RequestPending.requestPending[signalTp](reqFrame)){
      signal CXRequestQueue.receiveHandled[signalTp](error,
        layerCount,
        atFrame, reqFrame, 
        didReceive,
        microRef, t32kRef,
        md, msg);
    }else{
      cerror(TRANSPORT, "No pending rx to $x\r\n");
    }
    nextRX = (signalTp + 1)%NUM_RX_TRANSPORT_PROTOCOLS;
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (SUCCESS == error 
        && call AMPacket.destination(msg) == AM_BROADCAST_ADDR){
      lastBC = atFrame;
    }

    if (call CXPacketMetadata.getRequestedFrame(msg) != INVALID_FRAME){
      signal CXRequestQueue.sendHandled[CX_TP_SCHEDULED](
        error,
        layerCount,
        atFrame, reqFrame, microRef, t32kRef, md, msg);
    } else {
      signal CXRequestQueue.sendHandled[call CXTransportPacket.getProtocol(msg)](
        error,
        layerCount,
        atFrame, reqFrame, microRef, t32kRef, md, msg);
    }
  }

  //no good way to dispatch these at the moment. oh well.
  event void SubCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){}

  event void SubCXRQ.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){}

  command error_t SubProtocolSplitControl.start[uint8_t tp](){ return FAIL;}
  command error_t SubProtocolSplitControl.stop[uint8_t tp](){ return FAIL;}

  default event void CXRequestQueue.sendHandled[uint8_t tp](error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cerror(TRANSPORT, "!default t.sh: %x\r\n", tp);
  }

  default event void CXRequestQueue.receiveHandled[uint8_t tp](error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cerror(TRANSPORT, "default t.rh: %x\r\n", tp);
  }

  default event void SubProtocolSplitControl.startDone[uint8_t tp](error_t error){
  }
  default event void SubProtocolSplitControl.stopDone[uint8_t tp](error_t error){
  }

  default command bool RequestPending.requestPending[uint8_t tp](uint32_t frame){
    cerror(TRANSPORT, "default RP to %x\r\n", tp);
    return FALSE;
  }

  command uint32_t GetLastBroadcast.get(){
    return lastBC;
  }
}
