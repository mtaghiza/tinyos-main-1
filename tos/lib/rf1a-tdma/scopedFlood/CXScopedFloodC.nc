configuration CXScopedFloodC{
  provides interface Send[am_id_t type];
  provides interface Receive[am_id_t type];

  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface Resource;
  uses interface CXRoutingTable;
} implementation {
  components CXScopedFloodP;
  
  Send = CXScopedFloodP.Send;
  Receive = CXScopedFloodP.Receive;
  CXPacket = CXScopedFloodP.CXPacket;
  CXTDMA = CXScopedFloodP.CXTDMA;
  LayerPacket = CXScopedFloodP.LayerPacket;
  CXScopedFloodP.Resource = Resource;
  CXScopedFloodP.CXRoutingTable = CXRoutingTable;
  CXScopedFloodP.TDMARoutingSchedule = TDMARoutingSchedule;
}

