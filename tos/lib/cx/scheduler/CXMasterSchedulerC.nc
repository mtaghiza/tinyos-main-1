configuration CXMasterSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet;

} implementation {
  components CXMasterSchedulerP;
  components CXNetworkC;

  components CXSchedulerPacketC;
  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;

  CXMasterSchedulerP.SubCXRQ -> CXNetworkC;
  CXMasterSchedulerP.SubSplitControl -> CXNetworkC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;

  Packet = CXSchedulerPacketC;
}
