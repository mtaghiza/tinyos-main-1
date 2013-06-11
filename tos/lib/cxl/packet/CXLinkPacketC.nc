module CXLinkPacketC{
  provides interface Packet as PacketHeader;
  provides interface Packet as PacketBody;
} implementation {

  command void PacketHeader.clear(message_t* msg){
    memset(msg, 0, sizeof(message_t));
  }

  command void* PacketHeader.getPayload(message_t* msg, uint8_t len){
    return NULL;
  }
}
