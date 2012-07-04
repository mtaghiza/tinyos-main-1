configuration CXPacketStackC{
  provides interface CXPacket;
  provides interface CXPacketMetadata;
  provides interface AMPacket;
  provides interface Ieee154Packet;

  //required at interface with HPL
  provides interface Packet as Ieee154PacketBody;
  provides interface Packet as CXPacketBody;
  provides interface Packet as AMPacketBody;

  provides interface Rf1aPacket;
  provides interface PacketAcknowledgements;

} implementation {
  components CXTDMAPhysicalC;

  components new Rf1aIeee154PacketC() as Ieee154PacketC; 
  Ieee154PacketC.Rf1aPhysicalMetadata -> CXTDMAPhysicalC;
  components Ieee154AMAddressC;

  Ieee154Packet = Ieee154PacketC.Ieee154Packet;
  Ieee154PacketBody = Ieee154PacketC.Packet;
  Rf1aPacket = Ieee154PacketC.Rf1aPacket;


  components Rf1aCXPacketC;
  Rf1aCXPacketC.SubPacket -> Ieee154PacketC;
  Rf1aCXPacketC.Ieee154Packet -> Ieee154PacketC;
  Rf1aCXPacketC.Rf1aPacket -> Ieee154PacketC;
  Rf1aCXPacketC.ActiveMessageAddress -> Ieee154AMAddressC;

  components Rf1aAMPacketC as AMPacketC;
  AMPacketC.SubPacket -> Rf1aCXPacketC;
  AMPacketC.Ieee154Packet -> Ieee154PacketC;
  AMPacketC.Rf1aPacket -> Ieee154PacketC;
  AMPacketC.ActiveMessageAddress -> Ieee154AMAddressC;
  Rf1aCXPacketC.AMPacket -> AMPacketC;
  AMPacketBody = AMPacketC;

  CXPacketBody = Rf1aCXPacketC.Packet;
  CXPacket = Rf1aCXPacketC.CXPacket;
  CXPacketMetadata = Rf1aCXPacketC.CXPacketMetadata;
  AMPacket = AMPacketC;
  PacketAcknowledgements = Rf1aCXPacketC.PacketAcknowledgements;

}
