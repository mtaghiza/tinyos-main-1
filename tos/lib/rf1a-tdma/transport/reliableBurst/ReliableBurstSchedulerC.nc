configuration ReliableBurstSchedulerC{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule;
  uses interface SlotStarted;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
} implementation {
  components ReliableBurstSchedulerP;

  CXTransportSchedule = ReliableBurstSchedulerP.CXTransportSchedule;
  ReliableBurstSchedulerP.TDMARoutingSchedule = TDMARoutingSchedule;
  ReliableBurstSchedulerP.SlotStarted = SlotStarted;

  AMSend = ReliableBurstSchedulerP.AMSend;
  Receive = ReliableBurstSchedulerP.Receive;

  ReliableBurstSchedulerP.ScopedFloodSend = ScopedFloodSend;
  ReliableBurstSchedulerP.ScopedFloodReceive = ScopedFloodReceive;

  ReliableBurstSchedulerP.AMPacket = AMPacket;
  ReliableBurstSchedulerP.AMPacketBody = AMPacketBody;
  ReliableBurstSchedulerP.CXPacket = CXPacket;
  ReliableBurstSchedulerP.CXPacketMetadata = CXPacketMetadata;
}
