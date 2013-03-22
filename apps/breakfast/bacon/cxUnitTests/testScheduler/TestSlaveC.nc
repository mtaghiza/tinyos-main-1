configuration TestSlaveC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components CXSlaveSchedulerC;
  TestP.CXRequestQueue -> CXSlaveSchedulerC;
  TestP.SplitControl -> CXSlaveSchedulerC;

  TestP.Packet -> CXSlaveSchedulerC;

  TestP.SerialControl -> PlatformSerialC;
}
