
 #include "StorageVolumes.h"
 #include "RecordStorage.h"
 #include "message.h"
 #include "stdio.h"
// #define printf(...)
configuration TestAppC{
} implementation {
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components MainC;
  components TestP;

  components WatchDogC;

  components SerialPrintfC;
  components SerialStartC;

  components Msp430XV2ClockC;

  TestP.Boot -> MainC;
  TestP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  components new PoolC(message_t, 2);

  components new LogStorageC(VOLUME_RECORD, TRUE);
  components SettingsStorageC;
  SettingsStorageC.LogWrite -> LogStorageC;

//  components SerialActiveMessageC;
//  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as AMSenderC;
//
//  TestP.SplitControl -> SerialActiveMessageC;

//  components new RecordPushRequestC(VOLUME_RECORD, TRUE);
//  RecordPushRequestC.AMSend -> AMSenderC;
//  RecordPushRequestC.Pool -> PoolC;
//  RecordPushRequestC.Get -> TestP.Get;

}
