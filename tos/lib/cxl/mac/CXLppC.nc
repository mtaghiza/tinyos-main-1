configuration CXLppC {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  provides interface Packet;

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
  CXLppP.Packet -> CXMacPacketC.Packet;
  CXLppP.CXMacPacket -> CXMacPacketC.CXMacPacket;

  components new TimerMilliC() as ProbeTimer;
  components new TimerMilliC() as SleepTimer;
  CXLppP.ProbeTimer -> ProbeTimer;
  CXLppP.SleepTimer -> SleepTimer;

  components RandomC;
  CXLppP.Random -> RandomC;

}
