configuration TDMASchedulerC{
  provides interface SplitControl;
  provides interface TDMARoutingSchedule[uint8_t rm];

  uses interface TDMAPhySchedule;
  uses interface SplitControl as SubSplitControl;

  uses interface Send as FloodSend[uint8_t t];
  uses interface Receive as FloodReceive[uint8_t t];

  uses interface Send as ScopedFloodSend[uint8_t t];
  uses interface Receive as ScopedFloodReceive[uint8_t t];

  provides interface Send;
  provides interface Receive;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;
  uses interface CXRoutingTable;
  uses interface FrameStarted;
} implementation {
  #if TDMA_ROOT == 1
  #warning compiling as TDMA root.
  components RootSchedulerP as TDMASchedulerP;
  #else
  components NonRootSchedulerP as TDMASchedulerP;
  #endif
  
  SplitControl = TDMASchedulerP.SplitControl; 

  TDMASchedulerP.SubSplitControl = SubSplitControl;
  TDMASchedulerP.AnnounceSend = FloodSend[CX_TYPE_SCHEDULE];
  TDMASchedulerP.AnnounceReceive = FloodReceive[CX_TYPE_SCHEDULE];
  TDMASchedulerP.ReplySend = FloodSend[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.ReplyReceive = FloodReceive[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.TDMAPhySchedule = TDMAPhySchedule;
  TDMASchedulerP.Packet = Packet;
  TDMASchedulerP.CXPacket = CXPacket;
  TDMASchedulerP.CXRoutingTable = CXRoutingTable;
  TDMASchedulerP.CXPacketMetadata = CXPacketMetadata;
  TDMASchedulerP.AMPacket = AMPacket;
  TDMASchedulerP.FrameStarted = FrameStarted;

  components AODVSchedulerC;
  Send = AODVSchedulerC.Send;
  Receive = AODVSchedulerC.Receive;
  TDMARoutingSchedule = AODVSchedulerC.TDMARoutingSchedule;
  AODVSchedulerC.SubTDMARoutingSchedule ->
    TDMASchedulerP.TDMARoutingSchedule;
  AODVSchedulerC.FrameStarted = FrameStarted;

  AODVSchedulerC.FloodSend = FloodSend[CX_TYPE_DATA];
  AODVSchedulerC.FloodReceive = FloodReceive[CX_TYPE_DATA];
  AODVSchedulerC.ScopedFloodSend = ScopedFloodSend[CX_TYPE_DATA];
  AODVSchedulerC.ScopedFloodReceive = ScopedFloodReceive[CX_TYPE_DATA];

  AODVSchedulerC.AMPacket = AMPacket;
  AODVSchedulerC.CXPacket = CXPacket;
  AODVSchedulerC.Packet = Packet;
  AODVSchedulerC.Rf1aPacket = Rf1aPacket;
  AODVSchedulerC.Ieee154Packet = Ieee154Packet;

  AODVSchedulerC.CXRoutingTable = CXRoutingTable;
}
