module CXNetworkP {
  uses interface CXLinkPacket;
  uses interface CXNetworkPacket;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRequestQueue;

  uses interface Pool<cx_network_metadata_t>;
} implementation {

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
        call CXNetworkPacket.setOriginFrameNumber(msg,
          atFrame - call CXNetworkPacket.getRXHopCount(msg));
        call CXNetworkPacket.setOriginFrameStart(msg,
          t32kRef - (FRAMELEN_32K * call CXNetworkPacket.getRXHopCount(msg)));
        if (call CXNetworkPacket.getTTL(msg) > 0){
          if (shouldForward(msg)){
            call CXNetworkPacket.readyNextHop(msg);
            error = call SubCXRequestQueue.requestSend(
              0, //Forwarding: originates at THIS layer, not above.
              atFrame, CX_NETWORK_FORWARD_DELAY,
              TRUE, microRef, //use last RX as ref
              NULL,           //don't apply timestamp
              nmd, msg);      //pointer to stashed md
            if (SUCCESS == error){
              return;
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
    if (SUCCESS != error){
      printf("nSCXRQ.sh: %x\r\n", error);
      if (layerCount){
        signal CXRequestQueue.sendHandled(error, 
          layerCount-1,
          atFrame, reqFrame, microRef, t32kRef, 
          nmd->next,
          msg);
      }else{
        signal CXRequestQueue.receiveHandled(error,
          nmd->layerCount - 1,
          nmd->atFrame, nmd->reqFrame,
          TRUE, nmd->microRef, nmd->t32kRef,
          nmd->next, msg);
      }
      call Pool.put(nmd);
    } else if (CX_SELF_RETX && call CXNetworkPacket.getTTL(msg)){
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
      error = call SubCXRequestQueue.requestSend(
        layerCount,
        atFrame, CX_NETWORK_FORWARD_DELAY,
        TRUE, microRef,
        NULL,
        nmd, msg);
      if (error != SUCCESS){
        //TODO: need to signal relevant *handled event here so that
        //upper layer isn't left hanging.
        printf("SCXRQ.s: %x\r\n", error);
      }
    } else{

      //we are origin, so signal up as sendHandled.
      if (layerCount > 0 ){
        signal CXRequestQueue.sendHandled(error, 
          layerCount - 1,
          atFrame, reqFrame, microRef, t32kRef, 
          nmd->next, msg);
        call Pool.put(nmd);
      }else{
        //restore stashed reception info and signal up.
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
        return ENOMEM;
      }else{
        error_t error;
        nmd -> next = md; 
        nmd -> layerCount = layerCount;
        nmd -> reqFrame = baseFrame + frameOffset;
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
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
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
        return call SubCXRequestQueue.requestSend(
          nmd->layerCount + 1, 
          baseFrame, frameOffset, 
          useMicro, microRef, 
          tsLoc, 
          nmd, msg);
      }else{
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
      int32_t frameOffset){
    return call SubCXRequestQueue.requestWakeup(layerCount+1, baseFrame, frameOffset);
  }

  event void SubCXRequestQueue.wakeupHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.wakeupHandled(error, layerCount-1, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestFrameShift(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    return call SubCXRequestQueue.requestFrameShift(layerCount+1,baseFrame, frameOffset,
      frameShift);
  }

  event void SubCXRequestQueue.frameShiftHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, 
      uint32_t reqFrame){
    signal CXRequestQueue.frameShiftHandled(error, layerCount-1, atFrame, reqFrame);
  }
  
}
