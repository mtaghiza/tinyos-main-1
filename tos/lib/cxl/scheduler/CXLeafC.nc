configuration CXLeafC {
  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];
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

  components CXProbeScheduleC;
  CXSlaveP.Get -> CXProbeScheduleC;

  CTS = CXSlaveP;
}
