 #include "StorageVolumes.h"
 #include "message.h"
 #define printf(...) 
 #define printfflush(...) 
configuration RouterAppC{
} implementation {
  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
  #endif

  components MainC;
  components RouterP;

//  components PrintfC;
//  components SerialStartC;

  components new PoolC(message_t, 4);

  components new AutoPushC(VOLUME_RECORD, TRUE);
  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);

  AutoPushC.Pool -> PoolC;
  AutoPushC.AMSend -> AMSenderC;


  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> PoolC;

  AutoPushC.Get -> RouterP.Get;

  components ActiveMessageC;
  RouterP.SplitControl -> ActiveMessageC;
  RouterP.Boot -> MainC;

  components new AMReceiverC(AM_LOG_RECORD_DATA_MSG);
  RouterP.ReceiveData -> AMReceiverC;

  components new LogStorageC(VOLUME_RECORD, TRUE);
  RouterP.LogWrite -> LogStorageC;
  RouterP.Pool -> PoolC;
}
