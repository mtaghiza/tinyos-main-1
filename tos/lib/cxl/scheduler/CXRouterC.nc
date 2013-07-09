configuration CXRouterC {
  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  provides interface CXDownload;

  uses interface Pool<message_t>;
  provides interface CTS;
} implementation {
  components SlotSchedulerC;
  components CXRouterP;

  CXDownload = CXRouterP;

  CXRouterP.Neighborhood -> SlotSchedulerC;

  Send = SlotSchedulerC;
  Packet = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;

  SlotSchedulerC.SlotController -> CXRouterP;

  components CXWakeupC;
  CXRouterP.LppControl -> CXWakeupC;

  components CXAMAddressC;
  CXRouterP.ActiveMessageAddress -> CXAMAddressC;

  CTS = CXRouterP;
}
