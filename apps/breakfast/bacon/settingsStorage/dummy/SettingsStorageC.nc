configuration SettingsStorageC{
  provides interface SettingsStorage;
  uses interface LogWrite;
} implementation {
  components DummySettingsStorageP;
  SettingsStorage = DummySettingsStorageP;
  DummySettingsStorageP.LogWrite = LogWrite;
} 
