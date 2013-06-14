configuration CXLppC {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  provides interface Packet;
  provides interface CXMacPacket;

  uses interface Pool<message_t>;
} implementation {
  components CXLppP;
  LppControl = CXLppP;
  Send = CXLppP.Send;
  Receive = CXLppP.Receive;
  SplitControl = CXLppP.SplitControl;

  components CXLinkC;
  CXLppP.SubSplitControl -> CXLinkC.SplitControl;
  CXLppP.SubSend -> CXLinkC.Send;
  CXLppP.SubReceive -> CXLinkC.Receive;
  CXLppP.CXLink -> CXLinkC.CXLink;
  CXLppP.CXLinkPacket -> CXLinkC.CXLinkPacket;

  CXLinkC.Pool = Pool;
  CXLppP.Pool = Pool;
  
  components CXMacPacketC;
  CXMacPacketC.SubPacket -> CXLinkC.Packet;
  Packet = CXMacPacketC.Packet;
  CXMacPacket = CXMacPacketC.CXMacPacket;
  CXLppP.Packet -> CXMacPacketC.Packet;
  CXLppP.CXMacPacket -> CXMacPacketC.CXMacPacket;

  components new TimerMilliC() as ProbeTimer;
  components new TimerMilliC() as SleepTimer;
  components new TimerMilliC() as KeepAliveTimer;
  CXLppP.ProbeTimer -> ProbeTimer;
  CXLppP.SleepTimer -> SleepTimer;
  CXLppP.KeepAliveTimer -> KeepAliveTimer;

  components RandomC;
  CXLppP.Random -> RandomC;

}
