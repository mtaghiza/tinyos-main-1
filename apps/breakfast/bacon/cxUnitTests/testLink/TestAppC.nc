configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components CXLinkC;
  TestP.CXRequestQueue -> CXLinkC;
  TestP.SplitControl -> CXLinkC;

  TestP.Rf1aStatus -> CXLinkC;
  TestP.Rf1aPacket -> CXLinkC;
}
