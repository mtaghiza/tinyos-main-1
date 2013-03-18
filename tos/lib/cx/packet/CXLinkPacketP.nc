module CXLinkPacketP {
  provides interface CXLinkPacket;
  
  uses interface Ieee154Packet;
  uses interface Rf1aPacket;

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

}
