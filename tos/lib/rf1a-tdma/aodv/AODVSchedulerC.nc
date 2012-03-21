configuration AODVSchedulerC{
  provides interface TDMARoutingSchedule[uint8_t rm];
  uses interface TDMARoutingSchedule as SubTDMARoutingSchedule[uint8_t rm];
  uses interface FrameStarted;

  provides interface Send;
  provides interface Receive;

  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;

  uses interface CXRoutingTable;
} implementation {
  components AODVSchedulerP;

  TDMARoutingSchedule = AODVSchedulerP.TDMARoutingSchedule;
  Send = AODVSchedulerP.Send;
  Receive = AODVSchedulerP.Receive;
  AODVSchedulerP.SubTDMARoutingSchedule = SubTDMARoutingSchedule;
  AODVSchedulerP.FloodSend = FloodSend;
  AODVSchedulerP.FloodReceive = FloodReceive;
  AODVSchedulerP.ScopedFloodSend = ScopedFloodSend;
  AODVSchedulerP.ScopedFloodReceive = ScopedFloodReceive;
  AODVSchedulerP.AMPacket = AMPacket;
  AODVSchedulerP.CXPacket = CXPacket;
  AODVSchedulerP.Packet = Packet;
  AODVSchedulerP.Rf1aPacket = Rf1aPacket;
  AODVSchedulerP.Ieee154Packet = Ieee154Packet;

  AODVSchedulerP.CXRoutingTable = CXRoutingTable;
  AODVSchedulerP.FrameStarted = FrameStarted;
}
