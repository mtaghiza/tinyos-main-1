configuration CXLeafC {
  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];
  
  //This gives out the most-recently-observed root of each network.
  provides interface Get<am_addr_t>[uint8_t ns];
} implementation {
  components SlotSchedulerC;
  Send = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;
  Packet = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;
  
  components CXSlaveP;
  SlotSchedulerC.SlotController[NS_GLOBAL] -> CXSlaveP;
  SlotSchedulerC.SlotController[NS_SUBNETWORK] -> CXSlaveP;

  Get = CXSlaveP.GetRoot;

  components CXProbeScheduleC;
  CXSlaveP.GetProbeSchedule -> CXProbeScheduleC;

  CTS = CXSlaveP;
}
