interface CXSchedulerPacket {
  command uint8_t getScheduleNumber(message_t* msg);
  command void setScheduleNumber(message_t* msg, uint8_t sn);
}
