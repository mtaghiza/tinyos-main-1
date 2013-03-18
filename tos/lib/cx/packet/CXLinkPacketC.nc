configuration CXLinkPacketC{
  provides interface CXLinkPacket;
  provides interface Rf1aPacket;
  provides interface Packet;

} implementation {
  //The link layer does not add anything to the packet, it just reuses
  //elements of the 15.4 header.
  components new Rf1aIeee154PacketC();
  Rf1aPacket = Rf1aIeee154PacketC;

  components CXLinkPacketP;
  CXLinkPacketP.Ieee154Packet -> Rf1aIeee154PacketC;
  CXLinkPacketP.Rf1aPacket -> Rf1aIeee154PacketC;

  Packet = Rf1aIeee154PacketC;
  CXLinkPacket = CXLinkPacketP;
}
