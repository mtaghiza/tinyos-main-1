configuration CXSchedulerPacketC{
  provides interface Packet;
  provides interface CXSchedulerPacket;
} implementation {
  components CXSchedulerPacketP;

  components CXNetworkPacketC;
  CXSchedulerPacket = CXSchedulerPacketP;
  Packet = CXSchedulerPacketP;

  CXSchedulerPacketP.SubPacket -> CXNetworkPacketC;
}
