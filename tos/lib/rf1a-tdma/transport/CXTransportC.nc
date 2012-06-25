 #include "CXTransport.h"

configuration CXTransportC{ 
  provides interface AMSend as UnreliableBurstSend[am_id_t id]; 
  provides interface Receive as UnreliableBurstReceive[am_id_t id]; 

  provides interface AMSend as SimpleFloodSend[am_id_t id];
  provides interface Receive as SimpleFloodReceive[am_id_t id];

} implementation {
  components TDMASchedulerC;
  components CXNetworkC;
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components CXRoutingTableC;

  components UnreliableBurstSchedulerC;
  UnreliableBurstSchedulerC.TDMARoutingSchedule ->
    TDMASchedulerC.TDMARoutingSchedule;
  UnreliableBurstSchedulerC.SlotStarted -> TDMASchedulerC.SlotStarted;

  UnreliableBurstSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_UNRELIABLE_BURST];
  UnreliableBurstSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_UNRELIABLE_BURST];

  UnreliableBurstSchedulerC.ScopedFloodSend 
    -> CXNetworkC.ScopedFloodSend[CX_TP_UNRELIABLE_BURST];
  UnreliableBurstSchedulerC.ScopedFloodReceive 
    -> CXNetworkC.ScopedFloodReceive[CX_TP_UNRELIABLE_BURST];

  UnreliableBurstSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  UnreliableBurstSchedulerC.AMPacketBody 
    -> CXPacketStackC.AMPacketBody;
  UnreliableBurstSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  UnreliableBurstSchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  UnreliableBurstSend = UnreliableBurstSchedulerC.AMSend;
  UnreliableBurstReceive = UnreliableBurstSchedulerC.Receive;


  components SimpleFloodSchedulerC;
  
  SimpleFloodSend = SimpleFloodSchedulerC;
  SimpleFloodReceive = SimpleFloodSchedulerC;
  SimpleFloodSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  SimpleFloodSchedulerC.AMPacketBody -> CXPacketStackC.AMPacketBody;
  SimpleFloodSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  SimpleFloodSchedulerC.CXPacketMetadata 
    -> CXPacketStackC.CXPacketMetadata;
  SimpleFloodSchedulerC.TDMARoutingSchedule 
    -> TDMASchedulerC.TDMARoutingSchedule;
  SimpleFloodSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_SIMPLE_FLOOD];
  SimpleFloodSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_SIMPLE_FLOOD];

  CXNetworkC.CXTransportSchedule[CX_TP_UNRELIABLE_BURST] 
    -> UnreliableBurstSchedulerC.CXTransportSchedule;
  CXNetworkC.CXTransportSchedule[CX_TP_SIMPLE_FLOOD] 
    -> SimpleFloodSchedulerC.CXTransportSchedule;
}
