configuration AODVSchedulerC{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule as SubTDMARoutingSchedule;
  uses interface FrameStarted;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet as AMPacketBody;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;

  uses interface CXRoutingTable;
} implementation {
  components AODVSchedulerP;

  CXTransportSchedule = AODVSchedulerP.CXTransportSchedule;
  AMSend = AODVSchedulerP.AMSend;
  Receive = AODVSchedulerP.Receive;
  AODVSchedulerP.SubTDMARoutingSchedule = SubTDMARoutingSchedule;
  AODVSchedulerP.FloodSend = FloodSend;
  AODVSchedulerP.FloodReceive = FloodReceive;
  AODVSchedulerP.ScopedFloodSend = ScopedFloodSend;
  AODVSchedulerP.ScopedFloodReceive = ScopedFloodReceive;
  AODVSchedulerP.AMPacket = AMPacket;
  AODVSchedulerP.CXPacket = CXPacket;
  AODVSchedulerP.AMPacketBody = AMPacketBody;
  AODVSchedulerP.Rf1aPacket = Rf1aPacket;
  AODVSchedulerP.Ieee154Packet = Ieee154Packet;

  AODVSchedulerP.CXRoutingTable = CXRoutingTable;
  AODVSchedulerP.FrameStarted = FrameStarted;
}
