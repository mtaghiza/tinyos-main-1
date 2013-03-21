configuration CXMasterSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet;

} implementation {
  components CXMasterSchedulerP;
  components CXNetworkC;

  components CXSchedulerPacketC;
  SplitControl = CXMasterSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;

  CXMasterSchedulerP.SubCXRQ -> CXNetworkC;
  CXMasterSchedulerP.SubSplitControl -> CXNetworkC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;

  Packet = CXSchedulerPacketC;
}
