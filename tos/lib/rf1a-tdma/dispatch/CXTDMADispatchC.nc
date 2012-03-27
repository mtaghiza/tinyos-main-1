configuration CXTDMADispatchC{
  provides interface CXTDMA[uint8_t routingMethod];
  provides interface Resource[uint8_t routingMethod];

  uses interface CXTDMA as SubCXTDMA;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
} implementation {
  components CXTDMADispatchP;
  components new FcfsArbiterC(CXTDMA_RM_RESOURCE);

  Resource = FcfsArbiterC;
  CXTDMA = CXTDMADispatchP;

  //used to figure out how to multiplex CXTDMA control 
  CXTDMADispatchP.ArbiterInfo -> FcfsArbiterC;
  CXTDMADispatchP.SubCXTDMA = SubCXTDMA;
  CXTDMADispatchP.CXPacket = CXPacket;
  CXTDMADispatchP.CXPacketMetadata = CXPacketMetadata;

}
