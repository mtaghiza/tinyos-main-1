configuration SimpleFloodSchedulerC{
  provides interface Send;
  provides interface Receive;

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  provides interface CXTransportSchedule;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface TDMARoutingSchedule;
} implementation{
  //This should use the meta-scheduler to determine when its slots
  //occur, and will basically just use the pre-defined max depth to
  //determine how long to wait before allowing the next transmission.

  components SimpleFloodSchedulerP;

  Send = SimpleFloodSchedulerP;
  Receive = SimpleFloodSchedulerP;
  SimpleFloodSchedulerP.CXTransportSchedule = CXTransportSchedule;
  SimpleFloodSchedulerP.AMPacket = AMPacket;
  SimpleFloodSchedulerP.AMPacketBody = AMPacketBody;
  SimpleFloodSchedulerP.TDMARoutingSchedule = TDMARoutingSchedule;

  SimpleFloodSchedulerP.FloodSend = FloodSend;
  SimpleFloodSchedulerP.FloodReceive = FloodReceive;
  SimpleFloodSchedulerP.CXPacket = CXPacket;
  SimpleFloodSchedulerP.CXPacketMetadata = CXPacketMetadata;
}
