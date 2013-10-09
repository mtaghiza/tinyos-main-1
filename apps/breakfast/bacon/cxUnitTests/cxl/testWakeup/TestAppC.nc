configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;
  components CXWakeupC;

  #define AUTO_TEST 1

  #if AUTO_TEST == 1
  components AutoTestP as TestP;
  components new TimerMilliC();
  TestP.Timer -> TimerMilliC;
  #else
  components TestP;
  #endif
  components LedsC;

  TestP.SplitControl -> CXWakeupC;
  TestP.CXLink -> CXWakeupC;
  TestP.CXLinkPacket -> CXWakeupC;
  TestP.Receive -> CXWakeupC;
  TestP.Send -> CXWakeupC;
  TestP.LppControl -> CXWakeupC;
  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> CXWakeupC;

  components new PoolC(message_t, 3);
  CXWakeupC.Pool -> PoolC;
  TestP.Pool -> PoolC;

  components SettingsStorageC;
  components new DummyLogWriteC();
  SettingsStorageC.LogWrite -> DummyLogWriteC;

}
