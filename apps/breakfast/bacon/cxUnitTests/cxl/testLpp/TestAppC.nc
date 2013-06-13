configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXLppC;
  components TestP;
  components LedsC;

  TestP.SplitControl -> CXLppC;
  TestP.Receive -> CXLppC;
  TestP.Send -> CXLppC;
  TestP.LppControl -> CXLppC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> CXLppC;

  components new PoolC(message_t, 3);
  CXLppC.Pool -> PoolC;
  TestP.Pool -> PoolC;

}
