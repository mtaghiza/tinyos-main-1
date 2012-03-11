configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;

  components GlossyRf1aSettings125KC as Rf1aSettings;

  components new Rf1aPhysicalC();
  Rf1aPhysicalC.Rf1aConfigure -> Rf1aSettings;

  components new Rf1aIeee154PacketC() as Ieee154Packet; 
  Ieee154Packet.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  components Ieee154AMAddressC;

  components Rf1aAMPacketC as AMPacket;
  AMPacket.Ieee154Packet -> Ieee154Packet;
  AMPacket.SubPacket -> Ieee154Packet;
  AMPacket.Rf1aPacket -> Ieee154Packet;
  AMPacket.ActiveMessageAddress -> Ieee154AMAddressC;


  TestP.HplMsp430Rf1aIf -> Rf1aPhysicalC;
  TestP.Resource -> Rf1aPhysicalC;
  TestP.Rf1aPhysical -> Rf1aPhysicalC;
  TestP.Rf1aStatus -> Rf1aPhysicalC;

  TestP.Rf1aPacket -> Ieee154Packet;
  TestP.Ieee154Packet -> Ieee154Packet;
  TestP.AMPacket -> AMPacket;
  
}
