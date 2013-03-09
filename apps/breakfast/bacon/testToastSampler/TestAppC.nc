
 #include "StorageVolumes.h"
 #include "RecordStorage.h"
 #include "message.h"
// #include "printf.h"
 #define printf(...)
configuration TestAppC{
} implementation {
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components MainC;
  components TestP;

  components WatchDogC;

//  components PrintfC;
//  components SerialStartC;

  components Msp430XV2ClockC;

  TestP.Boot -> MainC;
  TestP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  components new PoolC(message_t, 2);

  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as AMSenderC;

  TestP.SplitControl -> SerialActiveMessageC;

  components new AutoPushC(VOLUME_RECORD, TRUE);
  AutoPushC.AMSend -> AMSenderC;
  AutoPushC.Pool -> PoolC;
  AutoPushC.Get -> TestP.Get;

}
