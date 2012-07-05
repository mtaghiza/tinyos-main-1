interface TDMARoutingSchedule{
  command uint16_t framesPerSlot();
//  async command bool isOrigin(uint16_t frameNum);
  command bool isSynched();
  command uint8_t maxRetransmit();
  command bool ownsFrame(uint16_t frameNum);
  command uint16_t framesLeftInSlot(uint16_t frameNum);
  command uint16_t maxDepth();
  command uint16_t currentFrame();
  command uint16_t getNumSlots();
}
