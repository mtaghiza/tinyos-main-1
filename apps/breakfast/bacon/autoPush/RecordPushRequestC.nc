 
 #include "message.h"
generic configuration RecordPushRequestC(volume_id_t VOLUME_ID, bool circular){
  //external component provides data destination
  uses interface Get<am_addr_t>;
  uses interface Pool<message_t>;
  uses interface AMSend;
  uses interface Receive;
} implementation {
  components new LogStorageC(VOLUME_ID, circular);
  components new LogNotifyC(VOLUME_ID);
  components new RecordPushRequestP();
  components SettingsStorageC;

  components MainC;  
  MainC.SoftwareInit -> RecordPushRequestP;

  
  //For finding end of log and setting thresholds
  RecordPushRequestP.LogWrite -> LogStorageC;
  RecordPushRequestP.SettingsStorage -> SettingsStorageC;

  //For deciding when to push
  RecordPushRequestP.LogNotify -> LogNotifyC;

  //For receiving recovery requests
  RecordPushRequestP.Receive = Receive;
  
  //For reading/pushing data
  RecordPushRequestP.AMSend = AMSend;
  RecordPushRequestP.LogRead -> LogStorageC;
  RecordPushRequestP.Get = Get;
  RecordPushRequestP.Pool = Pool;

}
