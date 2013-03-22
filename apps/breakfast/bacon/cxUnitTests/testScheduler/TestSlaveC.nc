configuration TestSlaveC{
} implementation {
  components MainC;
  components TestSlaveP as TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components CXSlaveSchedulerC;
  CXSlaveSchedulerC.Receive -> TestP;
  TestP.CXRequestQueue -> CXSlaveSchedulerC;
  TestP.SplitControl -> CXSlaveSchedulerC;

  TestP.Packet -> CXSlaveSchedulerC;

  TestP.SerialControl -> PlatformSerialC;
}
