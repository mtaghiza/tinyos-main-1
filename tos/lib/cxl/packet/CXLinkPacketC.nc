module CXLinkPacketC{
  provides interface Packet;
  provides interface CXLinkPacket;
} implementation {
  uint8_t sn = 0;
  
  message_metadata_t* md(message_t* msg){
    return (message_metadata_t*)(msg->metadata);
  }

  command void CXLinkPacket.setAllowRetx(message_t* msg, bool allowRetx){
    md(msg)->cx.retx = allowRetx;
  }

  command void CXLinkPacket.setTSLoc(message_t* msg, 
      nx_uint32_t* tsLoc){
    md(msg)->cx.tsLoc = tsLoc;
  }
  
  command void CXLinkPacket.setLen(message_t* msg, uint8_t len){
    md(msg)->rf1a.payload_length = len - sizeof(message_header_t);
  }

  command uint8_t CXLinkPacket.len(message_t* msg){
    return md(msg)->rf1a.payload_length + sizeof(message_header_t);
  }

  command cx_link_header_t* CXLinkPacket.getLinkHeader(message_t* msg){
    return (cx_link_header_t*)(msg->header);
  }

  command cx_link_metadata_t* CXLinkPacket.getLinkMetadata(message_t* msg){
    return &(md(msg)->cx);
  }

  command rf1a_metadata_t* CXLinkPacket.getPhyMetadata(message_t* msg){
    return &(md(msg)->rf1a);
  }

  command void Packet.clear(message_t* msg){
    memset(msg, 0, sizeof(message_t));
    //set up defaults: increment sn, allow retx from this buffer.
    ((cx_link_header_t*)(msg->header))->sn = sn++;
    md(msg)->cx.retx = TRUE;
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return msg->data;
    }else {
      return NULL;
    }
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return md(msg)->rf1a.payload_length;
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    md(msg)->rf1a.payload_length = len;
  }

  command uint8_t Packet.maxPayloadLength(){
    return TOSH_DATA_LENGTH;
  }

}
