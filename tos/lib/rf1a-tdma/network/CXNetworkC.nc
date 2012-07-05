configuration CXNetworkC {
  provides interface Send as FloodSend[uint8_t t];
  provides interface Receive as FloodReceive[uint8_t t];

  provides interface Send as ScopedFloodSend[uint8_t t];
  provides interface Receive as ScopedFloodReceive[uint8_t t];

  uses interface CXTransportSchedule[uint8_t tProto];

} implementation {
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components TDMASchedulerC;

  components CXTDMADispatchC;
  CXTDMADispatchC.SubCXTDMA -> CXTDMAPhysicalC;
  CXTDMADispatchC.CXPacket -> CXPacketStackC.CXPacket;
  CXTDMADispatchC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  //this is just used to keep the enumerated arbiter happy
  enum{
    CX_RM_FLOOD_UC = unique(CXTDMA_RM_RESOURCE),
  };

  components CXFloodC;
  CXFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_RM_FLOOD];
  CXFloodC.Resource -> CXTDMADispatchC.Resource[CX_RM_FLOOD];
  CXFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXFloodC.CXTransportSchedule = CXTransportSchedule;

  FloodSend = CXFloodC;
  FloodReceive = CXFloodC;

  //this is just used to keep the enumerated arbiter happy
  enum{
    CX_RM_SCOPEDFLOOD_UC = unique(CXTDMA_RM_RESOURCE),
  };

  components CXScopedFloodC;
  CXScopedFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_RM_SCOPEDFLOOD];
  CXScopedFloodC.Resource -> CXTDMADispatchC.Resource[CX_RM_SCOPEDFLOOD];
  CXScopedFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXScopedFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXScopedFloodC.AMPacket -> CXPacketStackC.AMPacket;
  CXScopedFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXScopedFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXScopedFloodC.CXTransportSchedule = CXTransportSchedule;

  ScopedFloodSend = CXScopedFloodC;
  ScopedFloodReceive = CXScopedFloodC;

  components CXRoutingTableC;
  CXScopedFloodC.CXRoutingTable -> CXRoutingTableC;

  CXFloodC.CXRoutingTable -> CXRoutingTableC;


}
