interface CXTransportPacket {
  command uint8_t getProtocol(message_t* msg);
  command uint8_t setProtocol(message_t* msg, uint8_t proto);
  command uint8_t getSubprotocol(message_t* msg);
  command uint8_t setSubprotocol(message_t* msg, uint8_t subProto);
}
