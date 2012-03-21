configuration CXFloodC{
  provides interface Send[am_id_t type];
  provides interface Receive[am_id_t type];

  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface Resource;
  uses interface CXRoutingTable;
} implementation {
  components CXFloodP;
  
  Send = CXFloodP.Send;
  Receive = CXFloodP.Receive;
  CXPacket = CXFloodP.CXPacket;
  CXTDMA = CXFloodP.CXTDMA;
  TDMARoutingSchedule = CXFloodP.TDMARoutingSchedule;
  LayerPacket = CXFloodP.LayerPacket;
  CXFloodP.Resource = Resource;
  CXFloodP.CXRoutingTable = CXRoutingTable;
}
