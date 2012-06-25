configuration UnreliableBurstSchedulerC{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule;
  uses interface SlotStarted;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
} implementation {
  components UnreliableBurstSchedulerP;

  CXTransportSchedule = UnreliableBurstSchedulerP.CXTransportSchedule;
  UnreliableBurstSchedulerP.TDMARoutingSchedule = TDMARoutingSchedule;
  UnreliableBurstSchedulerP.SlotStarted = SlotStarted;

  AMSend = UnreliableBurstSchedulerP.AMSend;
  Receive = UnreliableBurstSchedulerP.Receive;

  UnreliableBurstSchedulerP.FloodSend = FloodSend;
  UnreliableBurstSchedulerP.FloodReceive = FloodReceive;

  UnreliableBurstSchedulerP.ScopedFloodSend = ScopedFloodSend;
  UnreliableBurstSchedulerP.ScopedFloodReceive = ScopedFloodReceive;

  UnreliableBurstSchedulerP.AMPacket = AMPacket;
  UnreliableBurstSchedulerP.AMPacketBody = AMPacketBody;
  UnreliableBurstSchedulerP.CXPacket = CXPacket;
  UnreliableBurstSchedulerP.CXPacketMetadata = CXPacketMetadata;
}
