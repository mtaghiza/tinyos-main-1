interface TDMAPhySchedule{
  command error_t setSchedule(uint32_t startAt,
    uint16_t atFrameNum, uint32_t frameLen, 
    uint32_t fwCheckLen, uint16_t activeFrames, 
    uint16_t inactiveFrames, uint8_t symbolRate,
    uint8_t channel);

  async event void frameStarted(uint32_t startTime, uint16_t frameNum);
  async event int32_t getFrameAdjustment(uint16_t frameNum);
  async command uint32_t getNow();
}
