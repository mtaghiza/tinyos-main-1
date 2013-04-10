configuration CXTransportPacketC{
  provides interface Packet;
  provides interface CXTransportPacket;
} implementation {
  components CXTransportPacketP;

  components CXSchedulerPacketC;
  CXTransportPacket = CXTransportPacketP;
  Packet = CXTransportPacketP;

  CXTransportPacketP.SubPacket -> CXSchedulerPacketC;
}
