configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;

  components TestP;
  #if CX_ROUTER == 1
  components CXRouterC as Scheduler;
  TestP.CXDownload -> Scheduler;
  #else
  components CXLeafC as Scheduler;
  #endif

  components LedsC;

  TestP.SplitControl -> Scheduler;
  TestP.Receive -> Scheduler;
  TestP.Send -> Scheduler;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> Scheduler;

  components new PoolC(message_t, 4);
  Scheduler.Pool -> PoolC;
  TestP.Pool -> PoolC;

}
