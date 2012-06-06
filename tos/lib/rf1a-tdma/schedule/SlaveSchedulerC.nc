
 #include "schedule.h"
configuration SlaveSchedulerC{
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface Receive as AnnounceReceive;
  uses interface AMSend as RequestSend;
  uses interface Receive as ResponseReceive;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

} implementation {
  components SlaveSchedulerP;

  SlaveSchedulerP.AnnounceReceive = AnnounceReceive;
  SlaveSchedulerP.RequestSend = RequestSend;
  SlaveSchedulerP.ResponseReceive = ResponseReceive;

  SlaveSchedulerP.FrameStarted = FrameStarted;
  SlaveSchedulerP.TDMAPhySchedule = TDMAPhySchedule;

  TDMARoutingSchedule = SlaveSchedulerP.TDMARoutingSchedule;
  SplitControl = SlaveSchedulerP.SplitControl;
  SlaveSchedulerP.SubSplitControl = SubSplitControl;

}
