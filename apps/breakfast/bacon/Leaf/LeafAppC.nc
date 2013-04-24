 #include "StorageVolumes.h"
 #include "message.h"
 #define printf(...) 
 #define printfflush(...) 
configuration LeafAppC{
} implementation {
  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardC;
  #endif

  components MainC;
  components LeafP;

//  components PrintfC;
//  components SerialStartC;

  components new PoolC(message_t, 4);

  components new AutoPushC(VOLUME_RECORD, TRUE);
  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);
  AutoPushC.Pool -> PoolC;
  AutoPushC.AMSend -> AMSenderC;

  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> PoolC;

  //TODO: should be from scheduler
  AutoPushC.Get -> LeafP.Get;
  
  components new ToastSamplerC(VOLUME_RECORD, TRUE);

  components ActiveMessageC;
  LeafP.SplitControl -> ActiveMessageC;
  LeafP.Boot -> MainC;

}
