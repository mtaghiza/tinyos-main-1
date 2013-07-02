configuration SlotSchedulerC{

  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  uses interface Pool<message_t>;

  uses interface SlotController;

  provides interface Neighborhood;
} implementation {
  components CXWakeupC;
  components SlotSchedulerP;

  components new Timer32khzC() as SlotTimer;
  components new Timer32khzC() as FrameTimer;

  Send = SlotSchedulerP.Send;
  Receive = SlotSchedulerP.Receive;
  SplitControl = CXWakeupC.SplitControl;
  SlotSchedulerP.Pool = Pool;
  SlotSchedulerP.SlotController = SlotController;
  
  SlotSchedulerP.CXLink -> CXWakeupC.CXLink;
  SlotSchedulerP.LppControl -> CXWakeupC.LppControl;
  SlotSchedulerP.CXMacPacket -> CXWakeupC.CXMacPacket;
  SlotSchedulerP.SubSend -> CXWakeupC.Send;
  SlotSchedulerP.SubReceive -> CXWakeupC.Receive;

  components NeighborhoodC;
  SlotSchedulerP.Neighborhood -> NeighborhoodC;
  Neighborhood = NeighborhoodC;
  NeighborhoodC.LppProbeSniffer -> CXWakeupC;

  Packet = CXWakeupC.Packet;

}
