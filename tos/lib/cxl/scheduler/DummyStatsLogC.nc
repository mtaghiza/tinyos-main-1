module DummyStatsLogC{
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface Packet;
} implementation {
  command void StatsLog.logSlotStats(cx_link_stats_t stats, 
      uint16_t wakeupNum, uint16_t slotNum, 
      uint8_t slotRole){}
  command void StatsLog.logReception(message_t* msg,
      uint16_t wakeupNum, uint16_t slotNum){}
  command void StatsLog.logTransmission(message_t* msg, 
      uint16_t wakeupNum, uint16_t slotNum){}
  command void StatsLog.flush(){}
}
