configuration Rf1aCXPacketC{
  provides interface Packet;
  provides interface CXPacket;
  provides interface CXPacketMetadata;
  provides interface PacketAcknowledgements;
  uses interface Packet as SubPacket;
  uses interface Ieee154Packet;
  uses interface AMPacket;
  uses interface Rf1aPacket;
  uses interface ActiveMessageAddress;
} implementation {
  components Rf1aCXPacketP as PacketP;
  Packet = PacketP;
  CXPacket = PacketP;
  SubPacket = PacketP;
  Ieee154Packet = PacketP;
  Rf1aPacket = PacketP;
  AMPacket = PacketP;
  CXPacketMetadata = PacketP;
  PacketAcknowledgements = PacketP;
  PacketP.ActiveMessageAddress = ActiveMessageAddress;
}
