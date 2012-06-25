interface CXPacketMetadata{
  command void setPhyTimestamp(message_t* amsg, uint32_t ts);
  command uint32_t getPhyTimestamp(message_t* amsg);
//  command void setAlarmTimestamp(message_t* amsg, uint32_t ts);
//  command uint32_t getAlarmTimestamp(message_t* amsg);
  command void setFrameNum(message_t* amsg, uint16_t ts);
  command uint16_t getFrameNum(message_t* amsg);
  command void setReceivedCount(message_t* amsg, uint8_t rc);
  command uint8_t getReceivedCount(message_t* amsg);
  command void setSymbolRate(message_t* amsg, uint8_t symbolRate);
  command uint8_t getSymbolRate(message_t* amsg);
  command void setRequiresClear(message_t* amsg, bool rc);
  command bool getRequiresClear(message_t* amsg);

}
