interface TDMARoutingSchedule{
  async command uint16_t framesPerSlot();
  async command bool isOrigin(uint16_t frameNum);
  async command bool isSynched(uint16_t frameNum);
  async command uint8_t maxRetransmit();
  async command bool ownsFrame(am_addr_t nodeId, uint16_t frameNum);
}
