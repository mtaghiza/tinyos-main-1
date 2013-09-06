
#ifndef ENABLE_SETTINGS_CONFIG_FULL
#define ENABLE_SETTINGS_CONFIG_FULL 1
#endif

configuration BareSettingsStorageConfiguratorC {
  uses interface Receive as SetReceive;
#if ENABLE_SETTINGS_CONFIG_FULL == 1
  uses interface Receive as GetReceive;
  uses interface Receive as ClearReceive;
  uses interface AMSend as GetSend;
#else
  #warning No clear/set support
#endif

  uses interface Pool<message_t>;
  uses interface AMPacket;
} implementation{
  components SettingsStorageC;
  components SettingsStorageConfiguratorP;

  
  SettingsStorageConfiguratorP.SettingsStorage -> SettingsStorageC;

  SettingsStorageConfiguratorP.SetReceive = SetReceive;
#if ENABLE_SETTINGS_CONFIG_FULL == 1
  SettingsStorageConfiguratorP.GetReceive = GetReceive;
  SettingsStorageConfiguratorP.ClearReceive = ClearReceive;
  SettingsStorageConfiguratorP.GetSend = GetSend;
#endif
  SettingsStorageConfiguratorP.Pool = Pool;
  SettingsStorageConfiguratorP.AMPacket = AMPacket;
}
