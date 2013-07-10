configuration CXBaseStationC {

  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  provides interface CXDownload;

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];
} implementation {
  components SlotSchedulerC;

  components CXMasterP;

  CXDownload = CXMasterP;

  CXMasterP.Neighborhood -> SlotSchedulerC;

  Send = SlotSchedulerC;
  Packet = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;

  SlotSchedulerC.SlotController[NS_GLOBAL] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_ROUTER] -> CXMasterP;

  components CXWakeupC;
  CXMasterP.LppControl -> CXWakeupC;

  components CXAMAddressC;
  CXMasterP.ActiveMessageAddress -> CXAMAddressC;

  CTS[NS_GLOBAL] = CXMasterP.CTS[NS_GLOBAL];
  CTS[NS_ROUTER] = CXMasterP.CTS[NS_ROUTER];

}
