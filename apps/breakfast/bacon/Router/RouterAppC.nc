 #include "StorageVolumes.h"
 #include "message.h"
 #include "CXDebug.h"
 #include "router.h"
configuration RouterAppC{
} implementation {
  #if ENABLE_PRINTF == 1
  components SerialPrintfC;
  components SerialStartC;
  #endif

  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
  #endif

  components MainC;
  components RouterP;


  components new PoolC(message_t, 4);

  components new RecordPushRequestC(VOLUME_RECORD, TRUE);
  components new RouterAMSenderC(AM_LOG_RECORD_DATA_MSG);
  components CXLinkPacketC;

  RecordPushRequestC.Pool -> PoolC;
  RecordPushRequestC.AMSend -> RouterAMSenderC;
  RecordPushRequestC.Packet -> RouterAMSenderC;
  RecordPushRequestC.CXLinkPacket -> CXLinkPacketC;

  #ifndef ENABLE_SETTINGS_CONFIG
  #define ENABLE_SETTINGS_CONFIG 1
  #endif

  #if ENABLE_SETTINGS_CONFIG == 1
  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> PoolC;
  #else
  #warning SettingsStorageConfigurator disabled!
  #endif

  components SettingsStorageC;

  #ifndef ENABLE_SETTINGS_LOGGING
  #define ENABLE_SETTINGS_LOGGING 1
  #endif

  #if ENABLE_SETTINGS_LOGGING == 1
  components new LogStorageC(VOLUME_RECORD, TRUE) as SettingsLS;
  SettingsStorageC.LogWrite -> SettingsLS;
  #else
  #warning Disabled settings logging!
  components new DummyLogWriteC();
  SettingsStorageC.LogWrite -> DummyLogWriteC;
  #endif

  RecordPushRequestC.Get -> CXRouterC.Get[NS_ROUTER];

  components ActiveMessageC;
  RouterP.SplitControl -> ActiveMessageC;
  RouterP.Boot -> MainC;

  components new AMReceiverC(AM_LOG_RECORD_DATA_MSG);
  RouterP.ReceiveData -> AMReceiverC;
  RouterP.AMPacket -> AMReceiverC;

  components new LogStorageC(VOLUME_RECORD, TRUE);
  RouterP.LogWrite -> LogStorageC;
  RouterP.Pool -> PoolC;

  components CXRouterC;
  components new TimerMilliC();
  RouterP.CXDownload -> CXRouterC.CXDownload[NS_SUBNETWORK];
  RouterP.SettingsStorage -> SettingsStorageC;
  RouterP.Timer -> TimerMilliC;

  components new LogStorageC(VOLUME_RECORD, TRUE) 
    as NetworkMembershipLS;
  CXRouterC.LogWrite -> NetworkMembershipLS;

  components new AMReceiverC(AM_CX_DOWNLOAD) as CXDownloadReceive;
  RouterP.CXDownloadReceive -> CXDownloadReceive; 

}
