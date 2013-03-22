configuration TestMasterC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components CXMasterSchedulerC;
  TestP.CXRequestQueue -> CXMasterSchedulerC;
  TestP.SplitControl -> CXMasterSchedulerC;

  TestP.Packet -> CXMasterSchedulerC;

  TestP.SerialControl -> PlatformSerialC;
}
