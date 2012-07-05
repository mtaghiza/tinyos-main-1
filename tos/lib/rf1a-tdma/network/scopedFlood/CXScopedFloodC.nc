configuration CXScopedFloodC{
  provides interface Send[uint8_t tProto];
  provides interface Receive[uint8_t tProto];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface AMPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface TaskResource;
  uses interface CXRoutingTable;
  uses interface CXTransportSchedule[uint8_t tProto];

} implementation {
  components CXScopedFloodP;
  
  Send = CXScopedFloodP.Send;
  Receive = CXScopedFloodP.Receive;
  CXScopedFloodP.CXPacket = CXPacket;
  CXScopedFloodP.CXPacketMetadata = CXPacketMetadata;
  CXScopedFloodP.AMPacket = AMPacket;
  CXTDMA = CXScopedFloodP.CXTDMA;
  LayerPacket = CXScopedFloodP.LayerPacket;
  CXScopedFloodP.TaskResource = TaskResource;
  CXScopedFloodP.CXRoutingTable = CXRoutingTable;
  CXScopedFloodP.TDMARoutingSchedule = TDMARoutingSchedule;

  CXScopedFloodP.CXTransportSchedule = CXTransportSchedule;
}

