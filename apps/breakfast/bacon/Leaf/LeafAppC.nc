 #include "StorageVolumes.h"
 #include "message.h"
 #define printf(...) 
 #define printfflush(...) 
configuration LeafAppC{
} implementation {
  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
  #endif

  components MainC;
  components LeafP;

//  components PrintfC;
//  components SerialStartC;

  components new PoolC(message_t, 4);

  components new RecordPushRequestC(VOLUME_RECORD, TRUE);
  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);
  components new AMReceiverC(AM_LOG_RECORD_DATA_MSG);
  RecordPushRequestC.Pool -> PoolC;
  RecordPushRequestC.AMSend -> AMSenderC;
  RecordPushRequestC.Receive -> AMReceiverC;

  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> PoolC;

  //TODO: should be from scheduler
  RecordPushRequestC.Get -> LeafP.Get;
  
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components new BaconSamplerC(VOLUME_RECORD, TRUE);

  components ActiveMessageC;
  LeafP.SplitControl -> ActiveMessageC;
  LeafP.Boot -> MainC;

}
