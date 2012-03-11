interface CXTDMA{
  command error_t setSchedule(uint32_t startAt, uint32_t frameLen,
    uint16_t numFrames, uint32_t fwCheckLen);

  async event bool isTXFrame(uint16_t frameNum);

  async event bool getPacket(message_t** msg, uint8_t* len);

  async event void frameStarted(uint32_t startTime);
}
