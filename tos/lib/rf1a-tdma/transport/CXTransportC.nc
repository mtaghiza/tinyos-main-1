 #include "CXTransport.h"

configuration CXTransportC{ 
  provides interface Send[uint8_t tproto]; 
  provides interface Receive[uint8_t tproto]; 

} implementation {
  components TDMASchedulerC;
  components CXNetworkC;
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components CXRoutingTableC;
  components SimpleFloodSchedulerC;
  
  Send[CX_TP_SIMPLE_FLOOD] = SimpleFloodSchedulerC.Send;
  Receive[CX_TP_SIMPLE_FLOOD] = SimpleFloodSchedulerC.Receive;
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

  CXNetworkC.CXTransportSchedule[CX_TP_SIMPLE_FLOOD] 
    -> SimpleFloodSchedulerC.CXTransportSchedule;

#if INCLUDE_UNRELIABLE_BURST == 1
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
  UnreliableBurstSchedulerC.CXPacketBody 
    -> CXPacketStackC.CXPacketBody;
  UnreliableBurstSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  UnreliableBurstSchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  UnreliableBurstSchedulerC.CXRoutingTable -> CXRoutingTableC;

  Send[CX_TP_UNRELIABLE_BURST] = UnreliableBurstSchedulerC.Send;
  Receive[CX_TP_UNRELIABLE_BURST] = UnreliableBurstSchedulerC.Receive;
  CXNetworkC.CXTransportSchedule[CX_TP_UNRELIABLE_BURST] 
    -> UnreliableBurstSchedulerC.CXTransportSchedule;
#endif

#if INCLUDE_RELIABLE_BURST == 1
  components ReliableBurstSchedulerC;
  ReliableBurstSchedulerC.TDMARoutingSchedule ->
    TDMASchedulerC.TDMARoutingSchedule;
  ReliableBurstSchedulerC.SlotStarted -> TDMASchedulerC.SlotStarted;

  ReliableBurstSchedulerC.ScopedFloodSend 
    -> CXNetworkC.ScopedFloodSend[CX_TP_RELIABLE_BURST];
  ReliableBurstSchedulerC.ScopedFloodReceive 
    -> CXNetworkC.ScopedFloodReceive[CX_TP_RELIABLE_BURST];

  ReliableBurstSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  ReliableBurstSchedulerC.AMPacketBody 
    -> CXPacketStackC.AMPacketBody;
  ReliableBurstSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  ReliableBurstSchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  Send[CX_TP_RELIABLE_BURST] = ReliableBurstSchedulerC.Send;
  Receive[CX_TP_RELIABLE_BURST] = ReliableBurstSchedulerC.Receive;

  CXNetworkC.CXTransportSchedule[CX_TP_RELIABLE_BURST] 
    -> ReliableBurstSchedulerC.CXTransportSchedule;
#endif
}
