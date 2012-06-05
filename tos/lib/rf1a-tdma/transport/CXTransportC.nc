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

  components AODVSchedulerC;
  AODVSchedulerC.SubTDMARoutingSchedule ->
    TDMASchedulerC.TDMARoutingSchedule;
  AODVSchedulerC.FrameStarted -> CXTDMAPhysicalC.FrameStarted;

  AODVSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_UNRELIABLE_BURST];
  AODVSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_UNRELIABLE_BURST];

  AODVSchedulerC.ScopedFloodSend 
    -> CXNetworkC.ScopedFloodSend[CX_TP_UNRELIABLE_BURST];
  AODVSchedulerC.ScopedFloodReceive 
    -> CXNetworkC.ScopedFloodReceive[CX_TP_UNRELIABLE_BURST];

  AODVSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  AODVSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  AODVSchedulerC.AMPacketBody -> CXPacketStackC.AMPacketBody;
  AODVSchedulerC.Rf1aPacket -> CXPacketStackC.Rf1aPacket;
  AODVSchedulerC.Ieee154Packet -> CXPacketStackC.Ieee154Packet;

  AODVSchedulerC.CXRoutingTable -> CXRoutingTableC;

  UnreliableBurstSend = AODVSchedulerC.AMSend;
  UnreliableBurstReceive = AODVSchedulerC.Receive;


  components SimpleFloodSchedulerC;
  
  SimpleFloodSend = SimpleFloodSchedulerC;
  SimpleFloodReceive = SimpleFloodSchedulerC;
  SimpleFloodSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  SimpleFloodSchedulerC.AMPacketBody -> CXPacketStackC.AMPacketBody;
  SimpleFloodSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  SimpleFloodSchedulerC.FrameStarted -> CXTDMAPhysicalC.FrameStarted;
  SimpleFloodSchedulerC.TDMARoutingSchedule 
    -> TDMASchedulerC.TDMARoutingSchedule;
  SimpleFloodSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_SIMPLE_FLOOD];
  SimpleFloodSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_SIMPLE_FLOOD];

  CXNetworkC.CXTransportSchedule[CX_TP_UNRELIABLE_BURST] 
    -> AODVSchedulerC.CXTransportSchedule;
  CXNetworkC.CXTransportSchedule[CX_TP_SIMPLE_FLOOD] 
    -> SimpleFloodSchedulerC.CXTransportSchedule;
}
