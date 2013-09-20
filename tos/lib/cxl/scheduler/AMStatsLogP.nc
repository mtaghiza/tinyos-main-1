module AMStatsLogP {
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface Packet;

  uses interface AMSend as RadioSend;
  uses interface AMSend as RXSend;
  uses interface AMSend as TXSend;
  uses interface Pool<message_t>;

  uses interface Packet as SerialPacket;
} implementation {
  
  command void StatsLog.logSlotStats(cx_link_stats_t stats, 
      uint16_t wakeupNum, uint16_t slotNum, 
      uint8_t slotRole){
    message_t* msg = call Pool.get();
    if (msg != NULL){
      stats_log_radio_t* pl = call RadioSend.getPayload(msg,
        sizeof(stats_log_radio_t));
      call SerialPacket.clear(msg);
      //TODO: fill in pl
      if (SUCCESS != call RadioSend.send(0, msg,
          sizeof(stats_log_radio_t))){
        call Pool.put(msg);
      }
    }
  }

  event void RadioSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.logReception(message_t* msg,
      uint16_t wakeupNum, uint16_t slotNum){
    message_t* logMsg = call Pool.get();
    if (logMsg != NULL){
      stats_log_rx_t* pl = call RXSend.getPayload(logMsg, 
        sizeof(stats_log_rx_t));
      call SerialPacket.clear(logMsg);
      if (SUCCESS != call RXSend.send(0, logMsg, sizeof(stats_log_rx_t))){
        call Pool.put(logMsg);
      }
    }
  }

  event void RXSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.logTransmission(message_t* msg, 
      uint16_t wakeupNum, uint16_t slotNum){
    message_t* logMsg = call Pool.get();
    if (logMsg != NULL){
      stats_log_tx_t* pl = call TXSend.getPayload(logMsg, 
        sizeof(stats_log_tx_t));
      call SerialPacket.clear(logMsg);
      if (SUCCESS != call TXSend.send(0, logMsg, sizeof(stats_log_tx_t))){
        call Pool.put(logMsg);
      }
    }
  }

  event void TXSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.flush(){}
}
