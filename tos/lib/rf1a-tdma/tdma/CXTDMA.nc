interface CXTDMA{
  command error_t setSchedule(uint32_t startAt, uint32_t frameLen,
    uint32_t fwCheckLen, uint16_t activeFrames, 
    uint16_t inactiveFrames);

  async event rf1a_offmode_t frameType(uint16_t frameNum);

  async event bool getPacket(message_t** msg, uint8_t* len);
  async event void sendDone(error_t error);

  async event message_t* receive(message_t* msg, uint8_t len);

  async event void frameStarted(uint32_t startTime);
}
