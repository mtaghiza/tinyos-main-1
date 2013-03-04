 #include "message.h"
generic configuration AutoPushC(volume_id_t VOLUME_ID, bool circular){
  //external component provides data destination
  uses interface Get<am_addr_t>;
  uses interface Pool<message_t>;
  uses interface AMSend;
} implementation {
  components new LogStorageC(VOLUME_ID, circular);
  components new LogNotifyC(VOLUME_ID);
  components new AutoPushP();

  components SettingsStorageC;
  components MainC;
  
  //For finding end of log and setting thresholds
  AutoPushP.Boot -> MainC;
  AutoPushP.LogWrite -> LogStorageC;
  AutoPushP.SettingsStorage -> SettingsStorageC;

  //For deciding when to push
  AutoPushP.LogNotify -> LogNotifyC;

  //For reading/pushing data
  AutoPushP.AMSend = AMSend;
  AutoPushP.LogRead -> LogStorageC;
  AutoPushP.Get = Get;
  AutoPushP.Pool = Pool;

}
