configuration CXFloodC{
  provides interface Send;
  provides interface Receive;

  uses interface CXPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
} implementation {
  components CXFloodP;
  
  Send = CXFloodP.Send;
  Receive = CXFloodP.Receive;
  CXPacket = CXFloodP.CXPacket;
  CXTDMA = CXFloodP.CXTDMA;
  TDMAScheduler = CXFloodP.TDMAScheduler;
}
