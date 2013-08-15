configuration CXRouterC {
  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  provides interface CXDownload[uint8_t ns];

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];
  provides interface Get<am_addr_t>[uint8_t ns];

  uses interface LogWrite;
} implementation {
  components SlotSchedulerC;

  components CXMasterP;
  components CXSlaveP;

  CXDownload[NS_SUBNETWORK] = CXMasterP.CXDownload[NS_SUBNETWORK];

  CXMasterP.Neighborhood -> SlotSchedulerC;
  LogWrite = CXMasterP.LogWrite;

  components CXLinkPacketC;
  CXMasterP.CXLinkPacket -> CXLinkPacketC;

  Send = SlotSchedulerC;
  Packet = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;

  SlotSchedulerC.SlotController[NS_GLOBAL] -> CXSlaveP;
  SlotSchedulerC.SlotController[NS_SUBNETWORK] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_ROUTER] -> CXSlaveP;

  components CXWakeupC;
  CXMasterP.LppControl -> CXWakeupC;

  components CXAMAddressC;
  CXMasterP.ActiveMessageAddress -> CXAMAddressC;

  components CXProbeScheduleC;
  CXMasterP.GetProbeSchedule -> CXProbeScheduleC;
  CXSlaveP.GetProbeSchedule -> CXProbeScheduleC;

  CTS[NS_GLOBAL] = CXSlaveP.CTS[NS_GLOBAL];
  CTS[NS_SUBNETWORK] = CXMasterP.CTS[NS_SUBNETWORK];
  CTS[NS_ROUTER] = CXSlaveP.CTS[NS_ROUTER];

  Get[NS_GLOBAL] = CXSlaveP.GetRoot[NS_GLOBAL];
  Get[NS_SUBNETWORK] = CXMasterP.GetRoot[NS_SUBNETWORK];
  Get[NS_ROUTER] = CXSlaveP.GetRoot[NS_ROUTER];
  
  components SettingsStorageC;
  CXMasterP.SettingsStorage -> SettingsStorageC;
}
