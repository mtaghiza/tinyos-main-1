interface TDMARoutingSchedule{
  command uint16_t framesPerSlot();
  async event bool isOrigin(uint16_t frameNum);
  async event bool isForwardOK(uint16_t frameNum);
}
