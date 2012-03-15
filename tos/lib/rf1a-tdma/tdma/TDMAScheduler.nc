interface TDMAScheduler {
  //goes to each client
  event void scheduleReceived(uint16_t activeFrames, 
    uint16_t inactiveFrames, uint16_t framesPerSlot, 
    uint16_t maxRetransmit);

}
