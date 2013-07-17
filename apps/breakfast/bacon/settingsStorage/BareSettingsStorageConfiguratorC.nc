configuration BareSettingsStorageConfiguratorC {
  uses interface Receive as SetReceive;
  uses interface Receive as GetReceive;
  uses interface Receive as ClearReceive;
  uses interface AMSend as GetSend;

  uses interface Pool<message_t>;
  uses interface AMPacket;
} implementation{
  components SettingsStorageC;
  components SettingsStorageConfiguratorP;
  
  SettingsStorageConfiguratorP.SettingsStorage -> SettingsStorageC;

  SettingsStorageConfiguratorP.SetReceive = SetReceive;
  SettingsStorageConfiguratorP.GetReceive = GetReceive;
  SettingsStorageConfiguratorP.ClearReceive = ClearReceive;
  SettingsStorageConfiguratorP.GetSend = GetSend;

  SettingsStorageConfiguratorP.Pool = Pool;
  SettingsStorageConfiguratorP.AMPacket = AMPacket;
}
