interface CXSchedulerPacket {
  command uint8_t getScheduleNumber(message_t* msg);
  command void setScheduleNumber(message_t* msg, uint8_t sn);
  command void setOriginFrame(message_t* msg, uint32_t originFrame);
  command uint32_t getOriginFrame(message_t* msg);
}
