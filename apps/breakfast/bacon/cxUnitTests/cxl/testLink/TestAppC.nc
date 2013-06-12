configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXLinkC;
  components TestP;
  components LedsC;

  TestP.SplitControl -> CXLinkC;
  TestP.Receive -> CXLinkC;
  TestP.Send -> CXLinkC;
  TestP.CXLink -> CXLinkC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> CXLinkC;
  TestP.CXLinkPacket -> CXLinkC;

  components new PoolC(message_t, 3);
  CXLinkC.Pool -> PoolC;
  TestP.Pool -> PoolC;

  components new TimerMilliC();
  TestP.Timer -> TimerMilliC;
  TestP.Rf1aStatus -> CXLinkC;

}
