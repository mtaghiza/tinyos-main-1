interface CXPacketMetadata{
  command uint32_t getRequestedFrame(message_t* msg);
  command void setRequestedFrame(message_t* msg, uint32_t rf);
  command void setTSLoc(message_t* msg, nx_uint32_t* tsLoc);
  command nx_uint32_t* getTSLoc(message_t* msg);
}
