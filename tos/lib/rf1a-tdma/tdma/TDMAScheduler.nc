interface TDMAScheduler {
  command error_t setSchedule(uint32_t frameLen, uint32_t fwCheckLen,
    uint16_t activeFrames, uint16_t inactiveFrames, 
    uint16_t framesPerSlot, uint16_t maxRetransmit);

  event void scheduleReceived(uint16_t activeFrames, 
    uint16_t inactiveFrames, uint16_t framesPerSlot, 
    uint16_t maxRetransmit);

  event bool isRoot();
}
