configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXLinkC;
  components TestP;

  TestP.SplitControl -> CXLinkC;
  TestP.Receive -> CXLinkC;
  TestP.Send -> CXLinkC;
  TestP.CXLink -> CXLinkC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;

  components new PoolC(message_t, 3);
  CXLinkC.Pool -> PoolC;
  TestP.Pool -> PoolC;
}
