configuration CXFloodC{
  provides interface Send[am_id_t type];
  provides interface Receive[am_id_t type];

  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface CXTransportSchedule[uint8_t tProto];
  uses interface Resource;
  uses interface CXRoutingTable;
  uses interface Queue<message_t*>;
  uses interface Pool<message_t>;
} implementation {
  components CXFloodP;
  
  Send = CXFloodP.Send;
  Receive = CXFloodP.Receive;
  CXPacket = CXFloodP.CXPacket;
  CXTDMA = CXFloodP.CXTDMA;
  TDMARoutingSchedule = CXFloodP.TDMARoutingSchedule;
  CXTransportSchedule = CXFloodP.CXTransportSchedule;
  LayerPacket = CXFloodP.LayerPacket;
  CXFloodP.Resource = Resource;
  CXFloodP.CXRoutingTable = CXRoutingTable;
  CXFloodP.Queue = Queue;
  CXFloodP.Pool = Pool;
}
