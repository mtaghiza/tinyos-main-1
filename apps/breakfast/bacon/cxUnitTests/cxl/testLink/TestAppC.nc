configuration TestAppC {
} implementation {
  components CXLinkC;
  components TestP;

  TestP.SplitControl -> CXLinkC;
  TestP.Receive -> CXLinkC;
  TestP.Send -> CXLinkC;

  components MainC;
  TestP.Boot -> MainC;

  components PlatformSerialC;
  components SerialPrintfC;
  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;

  components new PoolC(message_t, 3);
  CXLinkC.Pool -> PoolC;
  TestP.Pool -> PoolC;
}
