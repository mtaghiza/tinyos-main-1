configuration TestC {
} implementation {
  components MainC;
  components TestP;
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  
  #ifndef CX_MASTER 
  #define CX_MASTER 0
  #endif

  #if CX_MASTER == 0
  components CXSlaveSchedulerC;
  CXSlaveSchedulerC.Receive -> TestP.Receive;
  #endif
  components CXSchedulerC as SchedulerC;


  TestP.CXRequestQueue -> SchedulerC;
  TestP.SplitControl -> SchedulerC;
  TestP.Packet -> SchedulerC;

}
