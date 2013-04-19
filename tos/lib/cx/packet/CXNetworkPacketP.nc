
 #include "CXNetwork.h"
module CXNetworkPacketP{
  provides interface CXNetworkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  uses interface CXLinkPacket;
} implementation {
  
  cx_metadata_t* metadata(message_t* msg){
    //am I losing my mind? why is it so ugly to get a pointer to this
    //struct?
    return &((message_metadata_t*)(msg -> metadata))->cx;
  }

  //CX header stuffs
  cx_network_header_t* getHeader(message_t* msg){
    return (cx_network_header_t*)(call SubPacket.getPayload(msg,
      sizeof(cx_network_header_t)));
  }

  command uint8_t CXNetworkPacket.getRXHopCount(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx->rxHopCount;
  }

  command void CXNetworkPacket.setRXHopCount(message_t* msg, 
      uint8_t rxHopCount){
    cx_metadata_t* cx = metadata(msg);
    cx -> rxHopCount = rxHopCount;
  }

  command uint32_t CXNetworkPacket.getOriginFrameNumber(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx -> originFrameNumber;
  }

  command void CXNetworkPacket.setOriginFrameNumber(message_t* msg,
      uint32_t originFrameNumber){
    cx_metadata_t* cx = metadata(msg);
    cx -> originFrameNumber = originFrameNumber;
  }

  command uint32_t CXNetworkPacket.getOriginFrameStart(message_t* msg){
    cx_metadata_t* cx = metadata(msg);
    return cx -> originFrameStart;
  }

  command void CXNetworkPacket.setOriginFrameStart(message_t* msg,
      uint32_t originFrameStart){
    cx_metadata_t* cx = metadata(msg);
    cx -> originFrameStart = originFrameStart;
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
