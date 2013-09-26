
 #include "CXLinkDebug.h"
 #include "CXLink.h"
module PrintfStatsLogP{
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;
  uses interface Packet;
} implementation {
  command void StatsLog.logSlotStats(cx_link_stats_t stats, 
      uint16_t wakeupNum, uint16_t slotNum, 
      uint8_t slotRole){
    cinfo(STATS_RADIO, "SS %u %u %lu %lu %lu %lu %lu %lu %lu %u\r\n",
      wakeupNum,
      slotNum,
      stats.total,
      stats.off,
      stats.idle,
      stats.sleep,
      stats.rx,
      stats.tx,
      stats.fstxon, 
      slotRole); //e.g. owner, origin, forwarder, slept
  }

  command void StatsLog.logReception(message_t* msg,
      uint16_t wakeupNum, uint16_t slotNum){
    cinfo(STATS, "R %u %u %u %u %u\r\n",
      wakeupNum,
      slotNum,
      call CXLinkPacket.source(msg),
      call CXLinkPacket.getSn(msg),
      call CXLinkPacket.rxHopCount(msg));
  }

  command void StatsLog.logTransmission(message_t* msg, 
      uint16_t wakeupNum, uint16_t slotNum){
    cinfo(STATS, "T %u %u %u %u %u %u\r\n",
      wakeupNum,
      slotNum, 
      call CXLinkPacket.getSn(msg),
      call Packet.payloadLength(msg),
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));
    //additional info: status neeeds to indicate DP
    if (call CXMacPacket.getMacType(msg) == CXM_STATUS){
      cx_status_t* status = (cx_status_t*) (call Packet.getPayload(msg, sizeof(cx_status_t)));
      cinfo(STATS, "S %u %u %u %u\r\n", 
        wakeupNum,
        slotNum, 
        call CXLinkPacket.getSn(msg),
        status->dataPending);
    }else if (call CXMacPacket.getMacType(msg) == CXM_EOS){
      cx_eos_t* eos = (cx_eos_t*) (call Packet.getPayload(msg,
        sizeof(cx_eos_t)));
      cinfo(STATS, "E %u %u %u %u\r\n", 
        wakeupNum,
        slotNum, 
        call CXLinkPacket.getSn(msg),
        eos->dataPending);
    }
  }

  command void StatsLog.flush(){
    cflushinfo(STATS);
  }
  
}
