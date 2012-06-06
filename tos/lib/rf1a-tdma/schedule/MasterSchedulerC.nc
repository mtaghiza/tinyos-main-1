
 #include "schedule.h"
configuration MasterSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface AMSend as AnnounceSend;
  uses interface Receive as RequestReceive;
  uses interface AMSend as ResponseSend;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
} implementation {
  components MasterSchedulerP;

  MasterSchedulerP.AnnounceSend = AnnounceSend; 
  MasterSchedulerP.RequestReceive = RequestReceive;
  MasterSchedulerP.ResponseSend = ResponseSend;

  MasterSchedulerP.FrameStarted = FrameStarted;
  MasterSchedulerP.TDMAPhySchedule = TDMAPhySchedule;

  TDMARoutingSchedule = MasterSchedulerP.TDMARoutingSchedule;

  SplitControl = MasterSchedulerP.SplitControl;
  MasterSchedulerP.SubSplitControl = SubSplitControl;
}
