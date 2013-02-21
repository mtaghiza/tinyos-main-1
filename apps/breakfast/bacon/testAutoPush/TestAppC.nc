
 #include "testAutoPush.h"
 #include "StorageVolumes.h"
configuration TestAppC{
} implementation {
  components MainC;
  
  components PrintfC;
  components SerialStartC;
  components WatchDogC;

  components new PoolC(message_t, 2);

  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as AMSenderC;

  components new AutoPushC(VOLUME_TEST, TRUE);
  AutoPushC.AMSend -> AMSenderC;
  AutoPushC.Pool -> PoolC;
  AutoPushC.Get -> TestP.Get;


  components TestP;
  components new LogStorageC(VOLUME_TEST, TRUE);
  components new TimerMilliC();

  TestP.Boot -> MainC;
  TestP.LogWrite -> LogStorageC;
  TestP.Timer -> TimerMilliC;
  TestP.SplitControl -> SerialActiveMessageC;
}
