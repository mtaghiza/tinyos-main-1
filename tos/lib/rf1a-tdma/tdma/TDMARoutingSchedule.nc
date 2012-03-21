interface TDMARoutingSchedule{
  async command uint16_t framesPerSlot();
  async command bool isOrigin(uint16_t frameNum);
  async command bool isForwardOK(uint16_t frameNum);
  async command uint16_t maxRetransmit();
}
