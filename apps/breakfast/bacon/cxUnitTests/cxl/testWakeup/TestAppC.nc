configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXWakeupC;
  components TestP;
  components LedsC;

  TestP.SplitControl -> CXWakeupC;
  TestP.CXLink -> CXWakeupC;
  TestP.CXLinkPacket -> CXWakeupC;
  TestP.Receive -> CXWakeupC;
  TestP.Send -> CXWakeupC;
  TestP.LppControl -> CXWakeupC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> CXWakeupC;

  components new PoolC(message_t, 3);
  CXWakeupC.Pool -> PoolC;
  TestP.Pool -> PoolC;

}
