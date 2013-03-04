 #include "CXNetwork.h"
configuration CXNetworkC {
  provides interface Send as FloodSend[uint8_t t];
  provides interface Receive as FloodReceive[uint8_t t];

  #if INCLUDE_SCOPED_FLOOD == 1
  provides interface Send as ScopedFloodSend[uint8_t t];
  provides interface Receive as ScopedFloodReceive[uint8_t t];
  #endif

  uses interface CXTransportSchedule[uint8_t tProto];

} implementation {
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components TDMASchedulerC;

  components CXTDMADispatchC;
  CXTDMADispatchC.SubCXTDMA -> CXTDMAPhysicalC;
  CXTDMADispatchC.CXPacket -> CXPacketStackC.CXPacket;
  CXTDMADispatchC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  components CXRoutingTableC;

  components CXFloodC;
  CXFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_FLOOD];
  CXFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_FLOOD];
  CXFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXFloodC.CXTransportSchedule = CXTransportSchedule;
  CXFloodC.CXRoutingTable -> CXRoutingTableC;

  FloodSend = CXFloodC;
  FloodReceive = CXFloodC;

  #if INCLUDE_SCOPED_FLOOD
  components CXScopedFloodC;
  CXScopedFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXScopedFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXScopedFloodC.AMPacket -> CXPacketStackC.AMPacket;
  CXScopedFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXScopedFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXScopedFloodC.CXTransportSchedule = CXTransportSchedule;
  CXScopedFloodC.CXRoutingTable -> CXRoutingTableC;

  ScopedFloodSend = CXScopedFloodC;
  ScopedFloodReceive = CXScopedFloodC;
  #endif




}
