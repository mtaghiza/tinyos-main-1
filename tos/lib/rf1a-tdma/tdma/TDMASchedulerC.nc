configuration TDMASchedulerC{
  provides interface SplitControl;
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface SplitControl as SubSplitControl;


  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface CXRoutingTable;
  uses interface FrameStarted;

} implementation {
  components CXTransportC;
  #if TDMA_ROOT == 1
  #warning compiling as TDMA root.
  components RootSchedulerP as TDMASchedulerP;
  #else
  components NonRootSchedulerP as TDMASchedulerP;
  #endif
  
  SplitControl = TDMASchedulerP.SplitControl; 

  TDMASchedulerP.SubSplitControl = SubSplitControl;
  TDMASchedulerP.AnnounceSend 
    -> CXTransportC.SimpleFloodSend[CX_TYPE_SCHEDULE];
  TDMASchedulerP.AnnounceReceive 
    -> CXTransportC.SimpleFloodReceive[CX_TYPE_SCHEDULE];
  TDMASchedulerP.ReplySend 
    -> CXTransportC.SimpleFloodSend[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.ReplyReceive 
    -> CXTransportC.SimpleFloodReceive[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.TDMAPhySchedule = TDMAPhySchedule;
  TDMASchedulerP.Packet = Packet;
  TDMASchedulerP.CXPacket = CXPacket;
  TDMASchedulerP.CXRoutingTable = CXRoutingTable;
  TDMASchedulerP.CXPacketMetadata = CXPacketMetadata;
  TDMASchedulerP.AMPacket = AMPacket;
  TDMASchedulerP.Rf1aPacket = Rf1aPacket;
  TDMASchedulerP.FrameStarted = FrameStarted;

  TDMARoutingSchedule = TDMASchedulerP;

}
