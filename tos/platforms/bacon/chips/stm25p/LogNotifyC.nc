generic configuration LogNotifyC(volume_id_t volume_id){
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;
//  uses interface Notify<uint8_t> as SubNotify;
} implementation {
  components LogNotifyCollectC;
  
  #ifndef ENABLE_CONFIGURABLE_LOG_NOTIFY
  #define ENABLE_CONFIGURABLE_LOG_NOTIFY 1
  #endif

  #if ENABLE_CONFIGURABLE_LOG_NOTIFY == 1
  components new LogNotifyP();
  #else 
  #warning "Disabled configurable push levels"
  components new LogNotifySingleP() as LogNotifyP;
  #endif
  components MainC;
  MainC.SoftwareInit -> LogNotifyP;

  LogNotifyP.SubNotify -> LogNotifyCollectC.Notify[volume_id];
  RecordsNotify = LogNotifyP.RecordsNotify;
//  BytesNotify = LogNotifyP.BytesNotify;
}
