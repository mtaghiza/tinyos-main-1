configuration TestAppC{
} implementation {
  components SettingsStorageConfiguratorC;
  components new PoolC(message_t, 4);
  components SerialPrintfC;
  components PlatformSerialC;

  SettingsStorageConfiguratorC.Pool -> PoolC;
  
  components TestP;
  components MainC;
  components ActiveMessageC;

  TestP.Boot -> MainC;
  TestP.SplitControl -> ActiveMessageC;

  TestP.StdControl -> PlatformSerialC;

}
