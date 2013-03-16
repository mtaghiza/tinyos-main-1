module CXNetworkP {
  provides interface CXNetworkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRequestQueue;
} implementation {

  bool shouldForward(message_t* msg){
    //TODO: check distance / is-broadcast
    return TRUE;
  }
  
  event void SubCXRequestQueue.receiveHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, message_t* msg){
    if (SUCCESS == error) {
      if (didReceive){
        //TODO: update distances
        if (call CXNetworkPacket.readyNextHop(msg)){
          if (shouldForward(msg)){
            error = call SubCXRequestQueue.requestSend(
              atFrame, 1,
              TRUE, microRef,
              NULL, msg);
            if (SUCCESS == error){
              //TODO: stash header/reception info (to signal up later)
              // hey, here's an idea: each requestX command should
              // also take in a void* that points to auxiliary info.
              // In this case, it would be a pointer to the original
              // reception state: timestamp, hop-count, etc.
              // This would also go into the request struct. 
              // These could be nested--
              //  Link layer stores message, timing info, ptr->network
              //    info
              //  network layer provides pointers to network info
              //    structs from network layer pool. 
              //    these can also contain pointers to aux info from
              //    the layer above.
              //  Transport layer: same deal.
              //I like this plan. It should be quite memory-efficient.
              return;
            }
          }
        }
      }
    }
    signal CXRequestQueue.receiveHandled(error, atFrame, reqFrame,
      didReceive, microRef, msg);
  }

  event void SubCXRequestQueue.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, message_t* msg){
    //TODO: still forwarding? see logic above, same as RX.
    //TODO: done forwarding? signal sendHandled if we are origin,
    //      restore stashed reception info and signal receiveHandled
    //      if we aren't.
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
      message_t* msg){
    return call SubCXRequestQueue.requestReceive(baseFrame, frameOffset,
      useMicro, microRef, duration, msg);
  }

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      message_t* msg){
    return call SubCXRequestQueue.requestSend(baseFrame, frameOffset, 
      useMicro, microRef, tsLoc, msg);
  }


  //CX header stuffs
  cx_network_header_t* getHeader(message_t* msg){
    return (cx_network_header_t*)(call SubPacket.getPayload(msg,
      sizeof(cx_network_header_t)));
  }

  command error_t CXNetworkPacket.init(message_t* msg){
    cx_network_header_t* hdr = getHeader(msg);
    hdr -> hops = 0;
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
