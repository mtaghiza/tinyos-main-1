interface CXPacketMetadata{
  command void setReceivedAt(message_t* amsg, uint32_t ts);
  command uint32_t getReceivedAt(message_t* amsg);
  command void setFrameNum(message_t* amsg, uint16_t ts);
  command uint16_t getFrameNum(message_t* amsg);
}
