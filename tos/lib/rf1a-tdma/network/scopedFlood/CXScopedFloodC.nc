configuration CXScopedFloodC{
  provides interface Send[am_id_t type];
  provides interface Receive[am_id_t type];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface AMPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface Resource;
  uses interface CXRoutingTable;
  uses interface CXTransportSchedule[uint8_t tProto];

  uses interface Queue<message_t*>;
  uses interface Pool<message_t>;
} implementation {
  components CXScopedFloodP;
  
  Send = CXScopedFloodP.Send;
  Receive = CXScopedFloodP.Receive;
  CXScopedFloodP.CXPacket = CXPacket;
  CXScopedFloodP.CXPacketMetadata = CXPacketMetadata;
  CXScopedFloodP.AMPacket = AMPacket;
  CXTDMA = CXScopedFloodP.CXTDMA;
  LayerPacket = CXScopedFloodP.LayerPacket;
  CXScopedFloodP.Resource = Resource;
  CXScopedFloodP.CXRoutingTable = CXRoutingTable;
  CXScopedFloodP.TDMARoutingSchedule = TDMARoutingSchedule;
  CXScopedFloodP.Queue = Queue;
  CXScopedFloodP.Pool = Pool;

  CXScopedFloodP.CXTransportSchedule = CXTransportSchedule;
}

