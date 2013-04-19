interface CXTransportPacket {
  command uint8_t getProtocol(message_t* msg);
  command void setProtocol(message_t* msg, uint8_t proto);
  command uint8_t getSubprotocol(message_t* msg);
  command void setSubprotocol(message_t* msg, uint8_t subProto);
}
