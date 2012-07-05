configuration CXFloodC{
  provides interface Send[uint8_t tProto];
  provides interface Receive[uint8_t tProto];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface CXTransportSchedule[uint8_t tProto];
  uses interface Resource;
  uses interface CXRoutingTable;
} implementation {
  components CXFloodP;
  
  Send = CXFloodP.Send;
  Receive = CXFloodP.Receive;
  CXPacket = CXFloodP.CXPacket;
  CXPacketMetadata = CXFloodP.CXPacketMetadata;
  CXTDMA = CXFloodP.CXTDMA;
  TDMARoutingSchedule = CXFloodP.TDMARoutingSchedule;
  CXTransportSchedule = CXFloodP.CXTransportSchedule;
  LayerPacket = CXFloodP.LayerPacket;
  CXFloodP.Resource = Resource;
  CXFloodP.CXRoutingTable = CXRoutingTable;
}
