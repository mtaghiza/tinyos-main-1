configuration CXMasterSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet;

} implementation {
  components CXMasterSchedulerP;
 
  components MainC;
  CXMasterSchedulerP.Boot -> MainC.Boot;
  components RandomC;
  CXMasterSchedulerP.Random -> RandomC;

  SplitControl = CXMasterSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;

  components CXNetworkC;
  CXMasterSchedulerP.SubCXRQ -> CXNetworkC;
  CXMasterSchedulerP.SubSplitControl -> CXNetworkC;

  components CXSchedulerPacketC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;
  Packet = CXSchedulerPacketC;
   
  //for addr
  components CXLinkPacketC;
  CXMasterSchedulerP.CXLinkPacket -> CXLinkPacketC;
  CXMasterSchedulerP.CXNetworkPacket -> CXNetworkC;

}
