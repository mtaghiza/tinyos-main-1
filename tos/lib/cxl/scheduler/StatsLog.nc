
 #include "CXLink.h"
interface StatsLog {
  command void logSlotStats(cx_link_stats_t stats, 
    uint16_t wakeupNum, int16_t slotNum, uint8_t slotRole);
  command void logReception(message_t* msg, 
    uint16_t wakeupNum, int16_t slotNum);
  command void logTransmission(message_t* msg, 
    uint16_t wakeupNum, int16_t slotNum);
  command void flush();
}
