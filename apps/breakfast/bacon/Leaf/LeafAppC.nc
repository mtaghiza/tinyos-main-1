 #include "StorageVolumes.h"
 #include "message.h"
 #include "CXDebug.h"
configuration LeafAppC{
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
  components LeafP;
  #ifndef PHOENIX_LOGGING
  #define PHOENIX_LOGGING 1
  #endif

  #if PHOENIX_LOGGING == 1
  //yeesh this is ugly
  components PhoenixNeighborhoodP;
  components new LogStorageC(VOLUME_RECORD, TRUE) as PhoenixLS;
  PhoenixNeighborhoodP.LogWrite -> PhoenixLS;
  #else
  #warning Phoenix disabled!
  #endif

  components new PoolC(message_t, 4);

  components new RecordPushRequestC(VOLUME_RECORD, TRUE);

  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);
  components new AMReceiverC(AM_CX_RECORD_REQUEST_MSG);
  components CXLinkPacketC;
  RecordPushRequestC.Pool -> PoolC;
  RecordPushRequestC.AMSend -> AMSenderC;
  RecordPushRequestC.Packet -> AMSenderC;
  RecordPushRequestC.CXLinkPacket -> CXLinkPacketC;
  RecordPushRequestC.Receive -> AMReceiverC;
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

//  components PingC;
//  PingC.Pool -> PoolC;

  components CXLeafC;
  RecordPushRequestC.Get -> CXLeafC.Get[NS_SUBNETWORK];
  
  #ifndef ENABLE_TOAST_SAMPLER
  #define ENABLE_TOAST_SAMPLER 1
  #endif

  #if ENABLE_TOAST_SAMPLER == 1
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  #else
  #warning Disabled Toast sampler!
  #endif

  #ifndef ENABLE_BACON_SAMPLER
  #define ENABLE_BACON_SAMPLER 1
  #endif

  #if ENABLE_BACON_SAMPLER == 1
  components new BaconSamplerC(VOLUME_RECORD, TRUE);
  #else
  #warning Disable Bacon sampler!
  #endif

  components ActiveMessageC;
  LeafP.SplitControl -> ActiveMessageC;
  LeafP.Boot -> MainC;

}
