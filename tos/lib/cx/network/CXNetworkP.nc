
 #include "CXLink.h"
 #include "CXNetwork.h"
module CXNetworkP {
  uses interface CXLinkPacket;
  uses interface CXNetworkPacket;
  uses interface CXPacketMetadata;
  uses interface AMPacket;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRequestQueue;

  uses interface Pool<cx_network_metadata_t>;
  uses interface RoutingTable;
} implementation {

  uint32_t synchFrame;
  uint32_t synchMicroRef;

  bool shouldForward(message_t* msg){
    bool ret = TRUE;
    if ( ! CX_SELF_RETX){
      ret = (call CXLinkPacket.getSource(msg) != call CXLinkPacket.addr());
    }
    //anything else we should be checking here?
    return ret;
  }

  cx_network_metadata_t* newMd(){
    cx_network_metadata_t* ret = call Pool.get();
    memset(ret, 0, sizeof(cx_network_metadata_t));
    return ret;
  }
  
  event void SubCXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, 
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*)md;
    nmd -> layerCount = layerCount;
    nmd -> atFrame = atFrame;
    nmd -> reqFrame = reqFrame;
    nmd -> microRef = microRef;
    nmd -> t32kRef = t32kRef;

    if (SUCCESS == error) {
      if (didReceive){
        call CXNetworkPacket.setRXHopCount(msg, 
          call CXNetworkPacket.getHops(msg));
        call RoutingTable.addMeasurement(call AMPacket.source(msg),
          TOS_NODE_ID, call CXNetworkPacket.getRXHopCount(msg));
        //RX hop-count is 1 when received in the original transmission
        //frame.
        call CXNetworkPacket.setOriginFrameNumber(msg,
          atFrame - (call CXNetworkPacket.getRXHopCount(msg) - 1));
        //n.b. this is an estimate of the CAPTURE time (in 32K units),
        //so, the PREP_TIME_32KHZ needs to be accounted for when
        //scheduling frames based on it. 
        printf_SKEW("ts %lu\r\n", t32kRef);
        call CXNetworkPacket.setOriginFrameStart(msg,
          t32kRef - (FRAMELEN_32K * (call CXNetworkPacket.getRXHopCount(msg) - 1)));
        if (call CXNetworkPacket.getTTL(msg) > 0){
          if (shouldForward(msg)){
            synchFrame = atFrame;
            synchMicroRef = microRef;
            call CXNetworkPacket.readyNextHop(msg);
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
              return;
            }else{
              printf("FWD %x\r\n", error);
            }
          }
        }
      }
    }
    //not forwarding, so we're done with it. signal up.
    signal CXRequestQueue.receiveHandled(error, 
      nmd->layerCount - 1,
      nmd->atFrame, nmd->reqFrame, 
      didReceive, nmd->microRef, nmd->t32kRef, 
      nmd->next, msg);
    call Pool.put(nmd);
  }

  event void SubCXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*) md;
    bool useMicroRef = TRUE;
    if (SUCCESS != error){
      printf("n.sh: %x\r\n", error);
    }
    if (SUCCESS == error){
      synchFrame = atFrame;
      synchMicroRef = microRef;
    }else if (atFrame - synchFrame > MAX_SOFT_SYNCH){
      useMicroRef =  FALSE;
    }

    if (SUCCESS == error && call CXNetworkPacket.getHops(msg) == 1){
      call CXNetworkPacket.setOriginFrameStart(msg,
        t32kRef);
    }
//      if (layerCount){
//        signal CXRequestQueue.sendHandled(error, 
//          layerCount-1,
//          atFrame, reqFrame, microRef, t32kRef, 
//          nmd->next,
//          msg);
//        call Pool.put(nmd);
//      }else{
//        //TODO: check TTL-- if it's still hot, try to send it again.
//        signal CXRequestQueue.receiveHandled(error,
//          nmd->layerCount - 1,
//          nmd->atFrame, nmd->reqFrame,
//          TRUE, nmd->microRef, nmd->t32kRef,
//          nmd->next, msg);
//        call Pool.put(nmd);
//      }
//    } 

    if (CX_SELF_RETX && call CXNetworkPacket.getTTL(msg)){
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
        printf("SCXRQ.s: %x\r\n", error);
        if (layerCount > 0){
          signal CXRequestQueue.sendHandled(error, 
            layerCount - 1,
            atFrame, nmd->reqFrame, microRef, t32kRef, 
            nmd->next, msg);
        } else {
          signal CXRequestQueue.receiveHandled(error,
            nmd -> layerCount - 1,
            nmd -> atFrame, nmd -> reqFrame,
            TRUE,  //we are forwarding, so we must have received
            nmd -> microRef, nmd -> t32kRef,
            nmd -> next,
            msg);
        }
        call Pool.put(nmd);
      }
    } else{

      //we are origin, so signal up as sendHandled.
      if (layerCount > 0 ){
        signal CXRequestQueue.sendHandled(error, 
          layerCount - 1,
          atFrame, nmd->reqFrame, microRef, t32kRef, 
          nmd->next, msg);
        call Pool.put(nmd);
      }else{
        //restore stashed reception info and signal up as receive
        signal CXRequestQueue.receiveHandled(error,
          nmd -> layerCount - 1,
          nmd -> atFrame, nmd -> reqFrame,
          TRUE,  //we are forwarding, so we must have received
          nmd -> microRef, nmd -> t32kRef,
          nmd -> next,
          msg);
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
      printf("net.cxrq.rr null\r\n");
      return EINVAL;
    } else{
      cx_network_metadata_t* nmd = newMd();
      if (nmd == NULL){
        printf("net.NOMEM\r\n");
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
        call CXNetworkPacket.setOriginFrameNumber(msg, 
          baseFrame + frameOffset);
        return call SubCXRequestQueue.requestSend(
          nmd->layerCount + 1, 
          baseFrame, frameOffset, 
          txPriority,
          useMicro, microRef, 
          nmd, msg);
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
  
}
