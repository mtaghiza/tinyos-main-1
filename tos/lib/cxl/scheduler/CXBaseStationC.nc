configuration CXBaseStationC {

  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  provides interface CXDownload[uint8_t ns];

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];

  provides interface Receive as StatusReceive;
  provides interface Get<am_addr_t>[uint8_t ns];
} implementation {
  components SlotSchedulerC;
  components CXProbeScheduleC;

  components CXMasterP;
  CXMasterP.GetProbeSchedule -> CXProbeScheduleC;

  CXDownload[NS_GLOBAL] = CXMasterP.CXDownload[NS_GLOBAL];
  CXDownload[NS_SUBNETWORK] = CXMasterP.CXDownload[NS_SUBNETWORK];
  CXDownload[NS_ROUTER] = CXMasterP.CXDownload[NS_ROUTER];

  CXMasterP.Neighborhood -> SlotSchedulerC;

  Send = SlotSchedulerC;
  Packet = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;

  SlotSchedulerC.SlotController[NS_GLOBAL] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_SUBNETWORK] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_ROUTER] -> CXMasterP;

  components CXWakeupC;
  CXMasterP.LppControl -> CXWakeupC;

  components CXAMAddressC;
  CXMasterP.ActiveMessageAddress -> CXAMAddressC;

  CTS[NS_GLOBAL] = CXMasterP.CTS[NS_GLOBAL];
  CTS[NS_SUBNETWORK] = CXMasterP.CTS[NS_SUBNETWORK];
  CTS[NS_ROUTER] = CXMasterP.CTS[NS_ROUTER];

  StatusReceive = CXMasterP.Receive;
  Get = CXMasterP.GetRoot;

  components SettingsStorageC;
  CXMasterP.SettingsStorage -> SettingsStorageC;
}
