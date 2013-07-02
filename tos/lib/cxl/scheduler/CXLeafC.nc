configuration CXLeafC {
  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  uses interface Pool<message_t>;
} implementation {
  components SlotSchedulerC;
  Send = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;
}
