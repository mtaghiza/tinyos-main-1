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


 #include "CXLink.h"
 #include "CXNetwork.h"
 #include "CXNetworkDebug.h"
 #include "CXSchedulerDebug.h"
module CXNetworkP {
  uses interface CXLinkPacket;
  uses interface CXNetworkPacket;
  uses interface CXPacketMetadata;
  uses interface AMPacket;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRequestQueue;

  uses interface Pool<cx_network_metadata_t>;
  uses interface RoutingTable;

  uses interface ActiveMessageAddress;
  //For better testbed logging 
  uses interface CXTransportPacket;
  uses interface Rf1aPacket;
  uses interface LocalTime<T32khz>;
  
  provides interface Notify<uint32_t> as ActivityNotify;

} implementation {

  uint32_t synchFrame;
  uint32_t synchMicroRef;

  command error_t ActivityNotify.enable(){
    return SUCCESS;
  }

  command error_t ActivityNotify.disable(){
    return FAIL;
  }

  cx_network_metadata_t* newMd(){
    cx_network_metadata_t* ret = call Pool.get();
    memset(ret, 0, sizeof(cx_network_metadata_t));
    return ret;
  }

  void printRX(message_t* msg, uint32_t t32kRef){
    //src, sn, local origin, hopCount at RX
    cinfo(NETWORK, "NRX %u %u %lu %u %lu %lu %u %i %u\r\n",
      call CXLinkPacket.getSource(msg),
      call CXNetworkPacket.getSn(msg),
      call CXNetworkPacket.getOriginFrameNumber(msg),
      call CXNetworkPacket.getRXHopCount(msg),
      t32kRef, call LocalTime.get(),
      call AMPacket.destination(msg),
      call Rf1aPacket.rssi(msg), call Rf1aPacket.lqi(msg));
  }
  
  uint32_t txOFN;
  uint8_t txHC;
  bool ptxPending = FALSE;
  
  task void printTXTask(){
    //local OFN, hopcount
    cinfo(NETWORK, "NFW %lu %u\r\n", txOFN, txHC);
    ptxPending = FALSE;
  }

  void printTX(message_t* msg, uint32_t atFrame){
    if (!ptxPending){
      txOFN = call CXNetworkPacket.getOriginFrameNumber(msg);
      txHC = call CXNetworkPacket.getHops(msg);
      ptxPending = TRUE;
      post printTXTask();
    }
  }

  void printOTX(message_t* msg){
    if ( call CXNetworkPacket.getOriginFrameStart(msg)){
      cinfo(NETWORK, "NTX ");
    } else {
      //dropped transmission
      cinfo(NETWORK, "NDT ");
    }

    cinfo(NETWORK, "%u %lu %lu %lu %u %u %u %u\r\n",
      call CXNetworkPacket.getSn(msg),
      call CXNetworkPacket.getOriginFrameNumber(msg),
      call CXNetworkPacket.getOriginFrameStart(msg),
      call LocalTime.get(),
      call AMPacket.destination(msg),
      call CXTransportPacket.getProtocol(msg),
      call CXTransportPacket.getSubprotocol(msg),
      call AMPacket.type(msg));
  }
  
  //looks like maybe the first schedule is getting dumped as a
  //duplicate?
  am_addr_t lastSrc = AM_BROADCAST_ADDR;
  uint16_t lastSn = 0xFFFF;

  bool isDuplicate(message_t* msg){
    return (lastSrc == call AMPacket.source(msg) 
      && lastSn == call CXNetworkPacket.getSn(msg));
  }
  
  event void SubCXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, 
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*)md;
    nmd -> layerCount = layerCount;
    nmd -> reqFrame = reqFrame;
    nmd -> microRef = microRef;
    nmd -> t32kRef = t32kRef;

    if (SUCCESS == error) {
      if (didReceive){
        signal ActivityNotify.notify(atFrame);
        call CXNetworkPacket.setRXHopCount(msg, 
          call CXNetworkPacket.getHops(msg));
        call RoutingTable.addMeasurement(call AMPacket.source(msg),
          call ActiveMessageAddress.amAddress(), call CXNetworkPacket.getRXHopCount(msg));
        //RX hop-count is 1 when received in the original transmission
        //frame.
        call CXNetworkPacket.setOriginFrameNumber(msg,
          atFrame - (call CXNetworkPacket.getRXHopCount(msg) - 1));
        //n.b. this is an estimate of the CAPTURE time (in 32K units),
        //so, the PREP_TIME_32KHZ needs to be accounted for when
        //scheduling frames based on it. 
        call CXNetworkPacket.setOriginFrameStart(msg,
          t32kRef - (FRAMELEN_32K * (call CXNetworkPacket.getRXHopCount(msg) - 1)));
        if (call CXNetworkPacket.getTTL(msg) > 0){
          synchFrame = atFrame;
          synchMicroRef = microRef;
          //do not timestamp.
          call CXPacketMetadata.setTSLoc(msg, NULL);
          error = call SubCXRequestQueue.requestSend(
            0, //Forwarding: originates at THIS layer, not above.
            synchFrame, CX_NETWORK_FORWARD_DELAY + (atFrame -
            synchFrame),
            TXP_FORWARD,
            TRUE, synchMicroRef, //use last RX as ref
            nmd, msg);      //pointer to stashed md
          if (SUCCESS == error){
            //prepare it after it's enqueued: otherwise, signalling it
            //up below produces a frame # mismatch.
            call CXNetworkPacket.readyNextHop(msg);
            return;
          }else{
            cerror(NETWORK, "FWD %x\r\n", error);
            //fall through
          }
        }
      }
    }

    //not forwarding, so we're done with it. signal up.
    if (didReceive){
      printRX(msg, nmd->t32kRef);
    }
    signal CXRequestQueue.receiveHandled(error, 
      nmd->layerCount - 1,
      atFrame, nmd->reqFrame, 
      didReceive && !isDuplicate(msg), nmd->microRef, nmd->t32kRef, 
      nmd->next, msg);
    synchFrame = 0;
    if (didReceive){
      lastSrc = call AMPacket.source(msg);
      lastSn = call CXNetworkPacket.getSn(msg);
    }
    call Pool.put(nmd);
  }

  event void SubCXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*) md;
    bool useMicroRef = TRUE;

    if (SUCCESS != error && ERETRY != error){
      cerror(NETWORK, "n.sh: %x\r\n", error);
    }
    if (SUCCESS == error){
      signal ActivityNotify.notify(atFrame);
      synchFrame = atFrame;
      synchMicroRef = microRef;
      printTX(msg, atFrame);
    }else if (atFrame - synchFrame > MAX_SOFT_SYNCH){
      useMicroRef =  FALSE;
      //TODO: if we are the source, synchFrame can be set to atFrame,
      //but useMicroRef should stay FALSE.
    }

    if (SUCCESS == error && call CXNetworkPacket.getHops(msg) == 1){
      call CXNetworkPacket.setOriginFrameStart(msg,
        t32kRef);
    }

    if (CX_SELF_RETX && call CXNetworkPacket.getTTL(msg) 
        && error != ERETRY){
      //if we were planning to timestamp it, but there was an error,
      //mark the timestamp as invalid: it's too messy to try to fix
      //this (has to be matched up with hop-count/origin frame, etc)
      if (error != SUCCESS && call CXPacketMetadata.getTSLoc(msg) != NULL){
        *(call CXPacketMetadata.getTSLoc(msg)) = INVALID_TIMESTAMP;
        call CXPacketMetadata.setTSLoc(msg, NULL);
      }
      //OK, so we obviously forwarded it last time, so let's do it
      //again. Use last TX as ref. 
      //now the frame # stuff is somewhat ambiguous: we have
      //transmitted it in multiple frames, so what is reqFrame and
      //what is atFrame? req = first, at=last?
      //what do we keep as the reference?
      call CXNetworkPacket.readyNextHop(msg);
      //layer count stays the same: e.g. if we are forwarding, this
      //  event is signalled with lc=0, and we should re-send with lc=0
      //  as well.  if we are origin, it will have lc > 0
      //do not timestamp.
      call CXPacketMetadata.setTSLoc(msg, NULL);
      //only use microref's from successfully-sent packets.
      error = call SubCXRequestQueue.requestSend(
        layerCount,
        synchFrame, 
        CX_NETWORK_FORWARD_DELAY + (atFrame - synchFrame),
        TXP_FORWARD,
        useMicroRef, synchMicroRef,
        nmd, msg);
      if (error != SUCCESS){
        //signal relevant *handled event here so that
        //upper layer isn't left hanging.
        cwarn(NETWORK, "SCXRQ.s: %x s %lu a %lu\r\n", error,
          synchFrame, atFrame);
        if (layerCount > 0){
          signal CXRequestQueue.sendHandled(error, 
            layerCount - 1,
            atFrame, nmd->reqFrame, microRef, t32kRef, 
            nmd->next, msg);
          synchFrame = 0;
        } else {
          printRX(msg, nmd -> t32kRef);
          signal CXRequestQueue.receiveHandled(error,
            nmd -> layerCount - 1,
            atFrame, nmd -> reqFrame,
            TRUE && !isDuplicate(msg),  //we are forwarding, so we must have received
            nmd -> microRef, nmd -> t32kRef,
            nmd -> next,
            msg);
          synchFrame = 0;
          lastSrc = call AMPacket.source(msg);
          lastSn = call CXNetworkPacket.getSn(msg);
        }
        call Pool.put(nmd);
      }
    } else{

      //we are origin, so signal up as sendHandled.
      if (layerCount > 0 ){
        printOTX(msg);
        signal CXRequestQueue.sendHandled(error, 
          layerCount - 1,
          atFrame, nmd->reqFrame, microRef, t32kRef, 
          nmd->next, msg);
        synchFrame = 0;
        call Pool.put(nmd);
      }else{
        //restore stashed reception info and signal up as receive
        printRX(msg, nmd -> t32kRef);
        signal CXRequestQueue.receiveHandled(error,
          nmd -> layerCount - 1,
          atFrame, nmd -> reqFrame,
          TRUE && !isDuplicate(msg),  //we are forwarding, so we must have received
          nmd -> microRef, nmd -> t32kRef,
          nmd -> next,
          msg);
        synchFrame = 0;
        lastSrc = call AMPacket.source(msg);
        lastSn = call CXNetworkPacket.getSn(msg);
        call Pool.put(nmd); 
      }
    }
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration,
      void* md,
      message_t* msg){
    if (msg == NULL){
      cerror(NETWORK, "net.cxrq.rr null\r\n");
      return EINVAL;
    } else{
      cx_network_metadata_t* nmd = newMd();
      if (nmd == NULL){
        cerror(NETWORK, "net.NOMEM\r\n");
        return ENOMEM;
      }else{
        error_t error;
        nmd -> next = md; 
        nmd -> layerCount = layerCount;
        nmd -> reqFrame = baseFrame + frameOffset;
        call CXNetworkPacket.setOriginFrameNumber(msg, 
          INVALID_FRAME);
        error = call SubCXRequestQueue.requestReceive(nmd->layerCount+1, baseFrame, frameOffset,
          useMicro, microRef, duration, nmd, msg);
        if (error != SUCCESS){
          call Pool.put(nmd);
        }
        return error;
      }
    }
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md,
      message_t* msg){
    cx_network_metadata_t* nmd = newMd();
    if (nmd == NULL){
      return ENOMEM;
    }else{
      nmd -> layerCount = layerCount;
      nmd -> next = md; 
      nmd -> reqFrame = baseFrame + frameOffset;
      //at this point, a new sequence number is assigned. We don't
      //want to call this lower (because then we will mess up SN's for
      //forwarded packets).
      call CXNetworkPacket.init(msg);
      if (call CXNetworkPacket.readyNextHop(msg)){
        error_t err;
        call CXNetworkPacket.setOriginFrameNumber(msg, 
          baseFrame + frameOffset);
        err =  call SubCXRequestQueue.requestSend(
          nmd->layerCount + 1, 
          baseFrame, frameOffset, 
          txPriority,
          useMicro, microRef, 
          nmd, msg);
        if (err != SUCCESS){
          call Pool.put(nmd);
        }
        return err;
      }else{
        call CXNetworkPacket.setOriginFrameNumber(msg,
          INVALID_FRAME);
        call Pool.put(nmd);
        //TTL was provided as 0.
        return EINVAL;
      }
    }
  }

  //------------  pass-throughs    --------
  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    return call SubCXRequestQueue.nextFrame(isTX);
  }

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRequestQueue.requestSleep(layerCount + 1, baseFrame, frameOffset);
  }
  event void SubCXRequestQueue.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, 
      uint32_t reqFrame){
    signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset,
    uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call SubCXRequestQueue.requestWakeup(layerCount+1,
      baseFrame, frameOffset, refFrame, refTime, correction);
  }

  event void SubCXRequestQueue.wakeupHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.wakeupHandled(error, layerCount-1, atFrame, reqFrame);
  }
  
  async event void ActiveMessageAddress.changed(){}
}
