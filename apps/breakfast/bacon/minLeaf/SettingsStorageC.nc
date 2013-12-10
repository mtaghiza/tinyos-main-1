configuration SettingsStorageC{
  provides interface SettingsStorage;
} implementation {
  components DummySettingsStorageP;
  SettingsStorage = DummySettingsStorageP;
} 
