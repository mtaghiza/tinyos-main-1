configuration ActiveMessageC {
  provides interface SplitControl;
  
  provides interface Packet;
  provides interface Rf1aPacket;
  provides interface CXPacket;
  provides interface AMPacket;

  provides interface CXPacketMetadata;

  //Separate paths for each transport protocol
  provides interface AMSend as UnreliableBurstSend[am_id_t id];
  provides interface AMSend as SimpleFloodSend[am_id_t id];
  provides interface AMSend as ReliableBurstSend[am_id_t id];

  //at receiver: no distinction
  provides interface Receive[am_id_t id];
  provides interface ReceiveNotify;

//  provides interface PacketAcknowledgements;
  provides interface TDMARoutingSchedule;
  provides interface SlotStarted;
  provides interface ScheduledSend as DefaultScheduledSend;

} implementation {
  components CXPacketStackC;

  components CXTDMAPhysicalC;
  components CXNetworkC;
  components CXTransportC;
  components CXRoutingTableC;

  components CombineReceiveP;
  CombineReceiveP.SimpleFloodReceive ->
    CXTransportC.SimpleFloodReceive;
  CombineReceiveP.UnreliableBurstReceive ->
    CXTransportC.UnreliableBurstReceive;
  CombineReceiveP.ReliableBurstReceive ->
    CXTransportC.ReliableBurstReceive;
  CombineReceiveP.CXPacket -> CXPacketStackC.CXPacket;
  CombineReceiveP.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CombineReceiveP.Rf1aPacket -> CXPacketStackC.Rf1aPacket;
  CombineReceiveP.AMPacket -> CXPacketStackC.AMPacket;
  CombineReceiveP.AMPacketBody -> CXPacketStackC.AMPacketBody;

  Receive = CombineReceiveP.Receive;
  ReceiveNotify = CombineReceiveP.ReceiveNotify;

  //this component is responsible for:
  // - receiving/distributing schedule-related packets
  // - instructing the phy layer how to configure itself
  // - telling the various routing methods when they are allowed to
  //   send.
  components TDMASchedulerC;

  //Scheduler: should sit above transport layer. So it should be
  //dealing with AM packets (using CX header as needed)
  TDMASchedulerC.SubSplitControl -> CXTDMAPhysicalC;

  TDMASchedulerC.TDMAPhySchedule -> CXTDMAPhysicalC;
  TDMASchedulerC.FrameStarted -> CXTDMAPhysicalC;

  SplitControl = TDMASchedulerC.SplitControl;
  SlotStarted = TDMASchedulerC.SlotStarted;
  TDMARoutingSchedule = TDMASchedulerC.TDMARoutingSchedule;
  DefaultScheduledSend = TDMASchedulerC.DefaultScheduledSend;

  AMPacket = CXPacketStackC.AMPacket;
  CXPacket = CXPacketStackC.CXPacket;
  CXPacketMetadata = CXPacketStackC.CXPacketMetadata;
  Packet = CXPacketStackC.AMPacketBody;
  Rf1aPacket = CXPacketStackC.Rf1aPacket;

  SimpleFloodSend = CXTransportC.SimpleFloodSend;
  UnreliableBurstSend = CXTransportC.UnreliableBurstSend;
  ReliableBurstSend = CXTransportC.ReliableBurstSend;

}
