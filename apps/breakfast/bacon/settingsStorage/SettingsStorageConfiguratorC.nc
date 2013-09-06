
  #include "SettingsStorage.h"
  #include "message.h"

configuration SettingsStorageConfiguratorC {
  uses interface Pool<message_t>;
} implementation {
  components SettingsStorageC;

  components new AMReceiverC(AM_SET_SETTINGS_STORAGE_MSG) 
    as SetReceive;
  #ifndef ENABLE_SETTINGS_CONFIG_FULL
  #define ENABLE_SETTINGS_CONFIG_FULL 1
  #endif

  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  components new AMReceiverC(AM_GET_SETTINGS_STORAGE_CMD_MSG) 
    as GetReceive;
  components new AMSenderC(AM_GET_SETTINGS_STORAGE_RESPONSE_MSG) 
    as GetSend;
  components new AMReceiverC(AM_CLEAR_SETTINGS_STORAGE_MSG) 
    as ClearReceive;
  #else
  #warning SettingsStorage: no clear/get support.
  #endif

  components SettingsStorageConfiguratorP;
  
  SettingsStorageConfiguratorP.SettingsStorage -> SettingsStorageC;
  SettingsStorageConfiguratorP.SetReceive -> SetReceive;
  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  SettingsStorageConfiguratorP.GetReceive -> GetReceive;
  SettingsStorageConfiguratorP.GetSend -> GetSend;
  SettingsStorageConfiguratorP.ClearReceive -> ClearReceive;
  #else
  #endif

  SettingsStorageConfiguratorP.AMPacket -> SetReceive;

  SettingsStorageConfiguratorP.Pool = Pool;
}
