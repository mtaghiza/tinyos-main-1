configuration SettingsStorageC{
  provides interface SettingsStorage;
} implementation {
  components TLVStorageC;
  //TODO: should be platform-defined
  components new TLVUtilsC(128);
  components SettingsStorageP;

  SettingsStorageP.TLVStorage -> TLVStorageC;
  SettingsStorageP.TLVUtils -> TLVUtilsC;

  SettingsStorage = SettingsStorageP;

} 
