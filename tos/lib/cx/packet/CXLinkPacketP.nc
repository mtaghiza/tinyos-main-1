module CXLinkPacketP {
  provides interface CXLinkPacket;
  provides interface Packet;
  uses interface Packet as SubPacket;
  
  uses interface Ieee154Packet;
  uses interface Rf1aPacket;
  uses interface CXPacketMetadata;

} implementation {
  command am_addr_t CXLinkPacket.getSource(message_t* msg){
    return call Ieee154Packet.source(msg);  
  }

  command void CXLinkPacket.setSource(message_t* msg, am_addr_t addr){
    call Ieee154Packet.setSource(msg, addr);
  }

  command am_addr_t CXLinkPacket.addr(){
    return call Ieee154Packet.address();
  }

  command void CXLinkPacket.init(message_t* msg){
    call Rf1aPacket.configureAsData(msg);
    call CXLinkPacket.setSource(msg, call CXLinkPacket.addr());
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
    call CXPacketMetadata.setRequestedFrame(msg, INVALID_FRAME);
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg);
  }
  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    call SubPacket.setPayloadLength(msg, len);
  }
  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength();
  }
  command void* Packet.getPayload(message_t* msg, uint8_t len){
    return call SubPacket.getPayload(msg, len);
  }


}
