configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXMacC;
  components CXLppC;
  components TestP;
  components LedsC;

  TestP.SplitControl -> CXMacC;
  TestP.Receive -> CXMacC;
  TestP.Send -> CXMacC;
  TestP.LppControl -> CXLppC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> CXMacC;

  components new PoolC(message_t, 3);
  CXMacC.Pool -> PoolC;
  TestP.Pool -> PoolC;
  
  components CXBasestationMacC;
  TestP.CXMacMaster -> CXBasestationMacC.CXMacMaster;
}
