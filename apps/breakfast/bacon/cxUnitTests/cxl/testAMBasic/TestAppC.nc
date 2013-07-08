configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;

  components ActiveMessageC;
  components CXLppC;

  components TestP;
  components LedsC;

  TestP.SplitControl -> ActiveMessageC;

  components new AMSenderC(AM_TEST_PAYLOAD);
  components new AMReceiverC(AM_TEST_PAYLOAD);
  TestP.Receive -> AMReceiverC;
  TestP.AMSend -> AMSenderC;

  TestP.LppControl -> CXLppC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> AMSenderC;

  TestP.Pool -> ActiveMessageC.Pool;

  components LocalTimeMilliC;
  TestP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC();
  TestP.PacketTimer -> TimerMilliC;
  
  #if CX_BASESTATION == 1
  components CXBasestationMacC;
  TestP.CXMacMaster -> CXBasestationMacC.CXMacMaster;
  #endif
}
