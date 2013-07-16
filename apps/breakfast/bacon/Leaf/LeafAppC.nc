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


  components new PoolC(message_t, 4);

  components new RecordPushRequestC(VOLUME_RECORD, TRUE);

  #if PHOENIX_LOGGING == 1
  //yeesh this is ugly
  components PhoenixNeighborhoodP;
  components new LogStorageC(VOLUME_RECORD, TRUE);
  PhoenixNeighborhoodP.LogWrite -> LogStorageC;
  #endif
  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);
  components new AMReceiverC(AM_CX_RECORD_REQUEST_MSG);
  RecordPushRequestC.Pool -> PoolC;
  RecordPushRequestC.AMSend -> AMSenderC;
  RecordPushRequestC.Receive -> AMReceiverC;

  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> PoolC;

//  components PingC;
//  PingC.Pool -> PoolC;

  //TODO: should be from scheduler
  RecordPushRequestC.Get -> LeafP.Get;
  
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
