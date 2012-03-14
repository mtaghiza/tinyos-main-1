configuration TDMASchedulerC{
  provides interface SplitControl;
  provides interface CXTDMA;

  uses interface SplitControl as SubSplitControl;
  uses interface CXTDMA as SubCXTDMA;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;
} implementation {
  components TDMASchedulerP;
  
  TDMASchedulerP.SplitControl = SplitControl;
  TDMASchedulerP.CXTDMA = CXTDMA;

  TDMASchedulerP.SubSplitControl = SubSplitControl;
  TDMASchedulerP.SubCXTDMA = SubCXTDMA;

  TDMASchedulerP.AMPacket = AMPacket;
  TDMASchedulerP.CXPacket = CXPacket;
  TDMASchedulerP.Packet = Packet;
  TDMASchedulerP.Rf1aPacket = Rf1aPacket;
  TDMASchedulerP.Ieee154Packet = Ieee154Packet;
}
