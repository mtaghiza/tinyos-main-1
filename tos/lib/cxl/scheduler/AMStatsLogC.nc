
 #include "AMStatsLog.h"
configuration AMStatsLogC{
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface Packet;
} implementation{
  components AMStatsLogP;
  components new SerialAMSenderC(AM_STATS_LOG_RADIO) as RadioSend;
  components new SerialAMSenderC(AM_STATS_LOG_RX) as RXSend;
  components new SerialAMSenderC(AM_STATS_LOG_TX) as TXSend;

  StatsLog = AMStatsLogP;
  AMStatsLogP.CXLinkPacket = CXLinkPacket;
  AMStatsLogP.Packet = Packet;

  AMStatsLogP.RadioSend -> RadioSend;
  AMStatsLogP.RXSend -> RXSend;
  AMStatsLogP.TXSend -> TXSend;
  AMStatsLogP.SerialPacket -> TXSend;

  components ActiveMessageC;
  AMStatsLogP.Pool -> ActiveMessageC;
}
