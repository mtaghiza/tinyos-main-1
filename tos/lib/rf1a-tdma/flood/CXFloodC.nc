configuration CXFloodC{
  provides interface Send;
  provides interface Receive;

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
