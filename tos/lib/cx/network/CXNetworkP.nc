module CXNetworkP {
  provides interface CXNetworkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  uses interface CXLinkPacket;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRequestQueue;

  uses interface Pool<cx_network_metadata_t>;
} implementation {

  bool shouldForward(message_t* msg){
    bool ret = TRUE;
    if ( ! CX_SELF_RETX){
      ret = (call CXLinkPacket.getSource(msg) != call CXLinkPacket.addr());
    }
    //TODO: check distance / is-broadcast, && it with ret
    return ret;
  }

  cx_network_metadata_t* newMd(){
    cx_network_metadata_t* ret = call Pool.get();
    memset(ret, 0, sizeof(cx_network_metadata_t));
    return ret;
  }
  
  event void SubCXRequestQueue.receiveHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, 
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*)md;
    nmd -> atFrame = atFrame;
    nmd -> reqFrame = reqFrame;
    nmd -> microRef = microRef;
    nmd -> t32kRef = t32kRef;

    if (SUCCESS == error) {
      if (didReceive){
        nmd -> rxHopCount = call CXNetworkPacket.getHops(msg);
        printf("#r %u %u\r\n", 
          call CXNetworkPacket.getHops(msg),
          call CXNetworkPacket.getTTL(msg));
        if (call CXNetworkPacket.getTTL(msg) > 0){
          if (shouldForward(msg)){
            call CXNetworkPacket.readyNextHop(msg);
            error = call SubCXRequestQueue.requestSend(
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
     nmd->atFrame, nmd->reqFrame, 
     didReceive, nmd->microRef, nmd->t32kRef, 
     nmd->next, msg);
    call Pool.put(nmd);
  }

  event void SubCXRequestQueue.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    cx_network_metadata_t* nmd = (cx_network_metadata_t*) md;
    if (SUCCESS != error){
      printf("SCXRQ.sh: %x\r\n", error);
      //TODO: signal relevant *handled event
    } else if (CX_SELF_RETX && call CXNetworkPacket.getTTL(msg)){
      //OK, so we obviously forwarded it last time, so let's do it
      //again. Use last TX as ref. 
      //now the frame # stuff is somewhat ambiguous: we have
      //transmitted it in multiple frames, so what is reqFrame and
      //what is atFrame? req = first, at=last?
      //what do we keep as the reference?
      call CXNetworkPacket.readyNextHop(msg);
      error = call SubCXRequestQueue.requestSend(
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
      if (call CXLinkPacket.getSource(msg) == call CXLinkPacket.addr()){
        signal CXRequestQueue.sendHandled(error, 
          atFrame, reqFrame, microRef, t32kRef, 
          nmd->next, msg);
        call Pool.put(nmd);
      }else{
        //restore stashed reception info and signal up.
        signal CXRequestQueue.receiveHandled(error,
          nmd -> atFrame, nmd -> reqFrame,
          TRUE,  //we are forwarding, so we must have received
          nmd -> microRef, nmd -> t32kRef,
          nmd -> next,
          msg);
        call Pool.put(nmd); 
      }
    }
  }


  //pass-throughs
  command uint32_t CXRequestQueue.nextFrame(){
    return call SubCXRequestQueue.nextFrame();
  }

  command error_t CXRequestQueue.requestSleep(uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRequestQueue.requestSleep(baseFrame, frameOffset);
  }
  event void SubCXRequestQueue.sleepHandled(error_t error, 
      uint32_t atFrame, 
      uint32_t reqFrame){
    signal CXRequestQueue.sleepHandled(error, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestWakeup(uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRequestQueue.requestWakeup(baseFrame, frameOffset);
  }

  event void SubCXRequestQueue.wakeupHandled(error_t error, uint32_t atFrame, 
      uint32_t reqFrame){
    signal CXRequestQueue.wakeupHandled(error, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestFrameShift(uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    return call SubCXRequestQueue.requestFrameShift(baseFrame, frameOffset,
      frameShift);
  }

  event void SubCXRequestQueue.frameShiftHandled(error_t error, uint32_t atFrame,
      uint32_t reqFrame){
    signal CXRequestQueue.frameShiftHandled(error, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestReceive(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration,
      void* md,
      message_t* msg){
    cx_network_metadata_t* nmd = newMd();
    if (nmd == NULL){
      return ENOMEM;
    }else{
      nmd -> next = md; 
      nmd -> reqFrame = baseFrame + frameOffset;
      return call SubCXRequestQueue.requestReceive(baseFrame, frameOffset,
        useMicro, microRef, duration, nmd, msg);
    }
  }

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md,
      message_t* msg){
    cx_network_metadata_t* nmd = newMd();
    if (nmd == NULL){
      return ENOMEM;
    }else{
      nmd -> next = md; 
      nmd -> reqFrame = baseFrame + frameOffset;
      //at this point, a new sequence number is assigned. We don't
      //want to call this lower (because then we will mess up SN's for
      //forwarded packets).
      call CXNetworkPacket.init(msg);
      return call SubCXRequestQueue.requestSend(baseFrame, frameOffset, 
        useMicro, microRef, 
        tsLoc, 
        nmd, msg);
    }
  }


  //CX header stuffs
  cx_network_header_t* getHeader(message_t* msg){
    return (cx_network_header_t*)(call SubPacket.getPayload(msg,
      sizeof(cx_network_header_t)));
  }

  command error_t CXNetworkPacket.init(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    hdr -> hops = 0;
    call CXLinkPacket.init(msg);
    return SUCCESS;
  }

  command void CXNetworkPacket.setTTL(message_t* msg, uint8_t ttl){
    cx_network_header_t* hdr = getHeader(msg);
    hdr -> ttl = ttl;
  }

  command uint8_t CXNetworkPacket.getTTL(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    return hdr->ttl;
  }

  command uint8_t CXNetworkPacket.getHops(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    return hdr->hops;
  }
  
  //if TTL positive, decrement TTL and increment hop count.
  //Return true if TTL is still positive after this step.
  command bool CXNetworkPacket.readyNextHop(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    if (hdr -> ttl > 0){
      hdr -> ttl --;
      hdr -> hops ++;
      return (hdr->ttl > 0);
    } else {
      return FALSE;
    }
  }
  //----------packet stuffs 
  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_network_header_t));
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_network_header_t);
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_network_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return (call SubPacket.getPayload(msg, sizeof(cx_network_header_t))) + sizeof(cx_network_header_t);
    } else {
      return NULL;
    }
  }

  
}
