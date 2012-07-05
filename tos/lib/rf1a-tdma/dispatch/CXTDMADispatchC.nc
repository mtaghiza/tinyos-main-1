configuration CXTDMADispatchC{
  provides interface CXTDMA[uint8_t routingMethod];
  provides interface TaskResource[uint8_t np];

  uses interface CXTDMA as SubCXTDMA;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
} implementation {
  components CXTDMADispatchP;

  TaskResource = CXTDMADispatchP.TaskResource;
  CXTDMA = CXTDMADispatchP;

  //used to figure out how to multiplex CXTDMA control 
  CXTDMADispatchP.SubCXTDMA = SubCXTDMA;
  CXTDMADispatchP.CXPacket = CXPacket;
  CXTDMADispatchP.CXPacketMetadata = CXPacketMetadata;

}
