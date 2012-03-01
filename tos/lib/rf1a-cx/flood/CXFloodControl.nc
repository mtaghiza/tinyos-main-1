interface CXFloodControl{
  command error_t setRoot(bool isRoot);
  command error_t setPeriod(uint32_t period);
  command error_t setFrameLen(uint32_t frameLen);
  command error_t setNumFrames(uint16_t numFrames);
  command error_t assignFrame(uint16_t index, am_addr_t nodeId);
  command error_t freeFrame(uint16_t index);

  command error_t claimFrame(uint16_t index);
  //TODO: frame request event for root
}
