configuration CXFloodC{
  provides interface Send[am_id_t type];
  provides interface Receive[am_id_t type];

  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
} implementation {
  components CXFloodP;
  
  Send = CXFloodP.Send;
  Receive = CXFloodP.Receive;
  CXPacket = CXFloodP.CXPacket;
  CXTDMA = CXFloodP.CXTDMA;
  TDMAScheduler = CXFloodP.TDMAScheduler;
  LayerPacket = CXFloodP.LayerPacket;
}
