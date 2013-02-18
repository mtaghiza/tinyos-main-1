
#include "SettingsStorage.h"
#include "message.h"

configuration SettingsStorageConfiguratorC {
  uses interface Pool<message_t>;
} implementation {
  components SettingsStorageC;

  components new AMReceiverC(AM_SET_SETTINGS_STORAGE_MSG) 
    as SetReceive;
  components new AMReceiverC(AM_GET_SETTINGS_STORAGE_CMD_MSG) 
    as GetReceive;
  components new AMSenderC(AM_GET_SETTINGS_STORAGE_RESPONSE_MSG) 
    as GetSend;
  components new AMReceiverC(AM_CLEAR_SETTINGS_STORAGE_MSG) 
    as ClearReceive;

  components SettingsStorageConfiguratorP;
  
  SettingsStorageConfiguratorP.SettingsStorage -> SettingsStorageC;
  SettingsStorageConfiguratorP.SetReceive -> SetReceive;
  SettingsStorageConfiguratorP.GetReceive -> GetReceive;
  SettingsStorageConfiguratorP.GetSend -> GetSend;
  SettingsStorageConfiguratorP.ClearReceive -> ClearReceive;

  SettingsStorageConfiguratorP.AMPacket -> GetSend;

  SettingsStorageConfiguratorP.Pool = Pool;
}
