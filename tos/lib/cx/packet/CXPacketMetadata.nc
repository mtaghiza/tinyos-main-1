interface CXPacketMetadata{
  command uint8_t getRequestedBy(message_t* msg);
  command void setRequestedBy(message_t* msg, uint8_t rb);
}
