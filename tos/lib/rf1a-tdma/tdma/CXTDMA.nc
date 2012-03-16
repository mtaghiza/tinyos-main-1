interface CXTDMA{
  command error_t setSchedule(uint32_t startAt,
    uint16_t atFrameNum, uint32_t frameLen, 
    uint32_t fwCheckLen, uint16_t activeFrames, 
    uint16_t inactiveFrames);

  async event rf1a_offmode_t frameType(uint16_t frameNum);

  async event bool getPacket(message_t** msg, uint8_t* len, uint16_t frameNum);
  async event void sendDone(message_t* msg, uint8_t len, 
    uint16_t frameNum, error_t error);

  async event message_t* receive(message_t* msg, uint8_t len, 
    uint16_t frameNum);

  async event void frameStarted(uint32_t startTime, uint16_t frameNum);

  async command uint32_t getNow();
}
