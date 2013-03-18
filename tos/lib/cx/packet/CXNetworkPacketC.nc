configuration CXNetworkPacketC{
  provides interface Packet;
  provides interface CXNetworkPacket;
} implementation {
  components CXNetworkPacketP;

  components CXLinkPacketC;
  CXNetworkPacketP.SubPacket -> CXLinkPacketC;
  CXNetworkPacketP.CXLinkPacket -> CXLinkPacketC;
  
  Packet = CXNetworkPacketP;
  CXNetworkPacket = CXNetworkPacketP;
}
