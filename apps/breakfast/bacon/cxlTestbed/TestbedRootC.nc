configuration TestbedRootC {
} implementation {
  #if ENABLE_PRINTF == 1
  components SerialStartC;
  components SerialPrintfC;
  #endif

  components WatchDogC;
  components StackGuardMilliC;

  components MainC; 
  components ActiveMessageC; 

  components TestbedRootP;
  TestbedRootP.Boot -> MainC.Boot;

  TestbedRootP.SplitControl -> ActiveMessageC.SplitControl;

  components CXBaseStationC;
  TestbedRootP.CXDownload -> CXBaseStationC.CXDownload;

  components new TimerMilliC();
  TestbedRootP.Timer -> TimerMilliC;
  
  #ifndef ENABLE_AUTOSENDER
  #define ENABLE_AUTOSENDER 0
  #endif
  #if ENABLE_AUTOSENDER == 1
  #warning Enabled auto-sender: TEST ONLY
  components AutoSenderC;
  #endif

  components SettingsStorageC;
  components new DummyLogWriteC();
  SettingsStorageC.LogWrite -> DummyLogWriteC;

}
