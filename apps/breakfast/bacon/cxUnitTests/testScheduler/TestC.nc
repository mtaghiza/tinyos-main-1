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

  #if CX_MASTER == 1
  components CXMasterSchedulerC as SchedulerC;
  #else
  components CXSlaveSchedulerC as SchedulerC;
  SchedulerC.Receive -> TestP.Receive;
  #endif


  TestP.CXRequestQueue -> SchedulerC;
  TestP.SplitControl -> SchedulerC;
  TestP.Packet -> SchedulerC;

}
