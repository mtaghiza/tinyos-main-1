interface ScheduledAMSend {
  
  command error_t send(am_addr_t addr, message_t* msg, uint8_t len,
    uint32_t frameNum);

  command error_t cancel(message_t* msg);
  event void sendDone(message_t* msg, error_t error);
  command uint8_t maxPayloadLength();
  command void* getPayload(message_t* msg, uint8_t len);
} 
