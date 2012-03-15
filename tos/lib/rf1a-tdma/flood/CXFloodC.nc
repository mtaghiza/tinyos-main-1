configuration FloodC{
  provides interface Send;
  provides interface Receive;

  uses interface CXPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
} implementation {
  components FloodP;
  
  Send = FloodP.Send;
  Receive = FloodP.Receive;
  CXPacket = FloodP.CXPacket;
  CXTDMA = FloodP.CXTDMA;
  TDMAScheduler = FloodP.TDMAScheduler;
}
