interface TDMARoutingSchedule{
  async command uint16_t framesPerSlot();
//  async command bool isOrigin(uint16_t frameNum);
  async command bool isSynched(uint16_t frameNum);
  async command uint8_t maxRetransmit();
  async command bool ownsFrame(uint16_t frameNum);
  async command uint16_t framesLeftInSlot(uint16_t frameNum);
  command uint16_t getDefaultSlot();
  command uint16_t getNumSlots();
}
