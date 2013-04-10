configuration TestC {
} implementation {
  components MainC, TestP;

  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;

  components CXTransportC;
  TestP.Send -> CXTransportC;
  TestP.Receive -> CXTransportC;
  TestP.SplitControl -> CXTransportC;
}
