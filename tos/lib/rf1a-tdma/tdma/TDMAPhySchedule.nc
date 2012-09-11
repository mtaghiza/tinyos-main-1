interface TDMAPhySchedule{
  command error_t setSchedule(uint32_t startAt,
    uint16_t atFrameNum, uint16_t totalFrames, uint8_t symbolRate,
    uint8_t channel, bool isSynched, bool skewCorrected);
  command uint32_t getFrameLen();

  async command uint32_t getNow();
  event uint8_t getScheduleNum();
  event void resynched(uint16_t frameNum);

  //TODO: should come from transport layer AND main schedule
  event bool isInactive(uint16_t frameNum);
}
