configuration SettingsStorageC{
  provides interface SettingsStorage;
  uses interface LogWrite;
} implementation {
  components TLVStorageC;
  //TODO: should be platform-defined
  components new TLVUtilsC(128);
  components SettingsStorageP;
  
  components MainC;
  SettingsStorageP.LogWrite = LogWrite;
  SettingsStorageP.Boot -> MainC.Boot;

  SettingsStorageP.TLVStorage -> TLVStorageC;
  SettingsStorageP.TLVUtils -> TLVUtilsC;

  SettingsStorage = SettingsStorageP;

  components RebootCounterC;
  components LocalTimeMilliC;
  SettingsStorageP.RebootCounter -> RebootCounterC;
  SettingsStorageP.LocalTime -> LocalTimeMilliC;

} 
