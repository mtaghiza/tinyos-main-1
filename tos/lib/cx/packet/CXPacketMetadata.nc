interface CXPacketMetadata{
  command uint32_t getRequestedFrame(message_t* msg);
  command void setRequestedFrame(message_t* msg, uint32_t rf);
}
