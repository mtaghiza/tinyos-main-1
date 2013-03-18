configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components CXNetworkC;
  TestP.CXRequestQueue -> CXNetworkC;
  TestP.SplitControl -> CXNetworkC;

  TestP.Packet -> CXNetworkC;
  TestP.CXNetworkPacket -> CXNetworkC;

  TestP.SerialControl -> PlatformSerialC;
}
