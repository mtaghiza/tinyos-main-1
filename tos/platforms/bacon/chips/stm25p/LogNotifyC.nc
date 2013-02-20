generic configuration LogNotifyC(volume_id_t volume_id){
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;
//  uses interface Notify<uint8_t> as SubNotify;
} implementation {
  components LogNotifyCollectC;

  components new LogNotifyP();
  components MainC;
  MainC.SoftwareInit -> LogNotifyP;

  LogNotifyP.SubNotify -> LogNotifyCollectC.Notify[volume_id];
  RecordsNotify = LogNotifyP.RecordsNotify;
//  BytesNotify = LogNotifyP.BytesNotify;
}
