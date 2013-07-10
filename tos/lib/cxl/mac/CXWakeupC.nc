configuration CXWakeupC {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  provides interface Packet;
  provides interface CXMacPacket;
  provides interface CXLink;
  provides interface CXLinkPacket;

  provides interface LppProbeSniffer;

  uses interface Pool<message_t>;
} implementation {
  components CXWakeupP;
  LppControl = CXWakeupP;
  Send = CXWakeupP.Send;
  Receive = CXWakeupP.Receive;
  SplitControl = CXWakeupP.SplitControl;
  CXLink = CXWakeupP.CXLink;

  components CXLinkC;
  CXWakeupP.SubSplitControl -> CXLinkC.SplitControl;
  CXWakeupP.SubSend -> CXLinkC.Send;
  CXWakeupP.SubReceive -> CXLinkC.Receive;
  CXWakeupP.SubCXLink -> CXLinkC.CXLink;
  CXWakeupP.CXLinkPacket -> CXLinkC.CXLinkPacket;
  CXWakeupP.LinkPacket -> CXLinkC.Packet;

  CXLinkC.Pool = Pool;
  CXWakeupP.Pool = Pool;
  CXLinkPacket = CXLinkC;
  
  components CXMacPacketC;
  CXMacPacketC.SubPacket -> CXLinkC.Packet;
  Packet = CXMacPacketC.Packet;
  CXMacPacket = CXMacPacketC.CXMacPacket;
  CXWakeupP.Packet -> CXMacPacketC.Packet;
  CXWakeupP.CXMacPacket -> CXMacPacketC.CXMacPacket;

  components new TimerMilliC() as ProbeTimer;
  components new TimerMilliC() as TimeoutCheck;
  CXWakeupP.ProbeTimer -> ProbeTimer;
  CXWakeupP.TimeoutCheck -> TimeoutCheck;

  components RandomC;
  CXWakeupP.Random -> RandomC;

  components StateDumpC;
  CXWakeupP.StateDump -> StateDumpC;

  LppProbeSniffer = CXWakeupP.LppProbeSniffer;

  components CXProbeScheduleC;
  CXWakeupP.Get -> CXProbeScheduleC;

}
