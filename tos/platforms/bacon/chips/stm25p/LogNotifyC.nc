configuration LogNotifyC{
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;
  uses interface Notify<uint8_t> as SubNotify;
} implementation {
  components LogNotifyP;
  components MainC;
  MainC.SoftwareInit -> LogNotifyP;

  LogNotifyP.SubNotify = SubNotify;
  RecordsNotify = LogNotifyP.RecordsNotify;
//  BytesNotify = LogNotifyP.BytesNotify;
}
