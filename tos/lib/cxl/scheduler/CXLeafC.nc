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
  
  components CXLeafP;
  SlotSchedulerC.SlotController -> CXLeafP;

  CTS = CXLeafP;
}
