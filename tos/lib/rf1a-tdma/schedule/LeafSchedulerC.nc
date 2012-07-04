#include "schedule.h"
#include "CXTransport.h" 
 
configuration LeafSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
  provides interface SlotStarted;
  provides interface ScheduledSend as DefaultScheduledSend;
} implementation{
  components SlaveSchedulerC;
  components CXTransportC;
  
  SlaveSchedulerC.FrameStarted = FrameStarted;
  SlaveSchedulerC.TDMAPhySchedule = TDMAPhySchedule;

  TDMARoutingSchedule = SlaveSchedulerC;
  SplitControl = SlaveSchedulerC.SplitControl;
  SlotStarted = SlaveSchedulerC.SlotStarted;
  SlaveSchedulerC.SubSplitControl = SubSplitControl;

  components new AMReceiverC(AM_ID_LEAF_SCHEDULE) as AnnounceReceive;
  components new AMSenderC(AM_ID_LEAF_REQUEST)
    as RequestSend;
  components new AMReceiverC(AM_ID_LEAF_RESPONSE) as ResponseReceive;

  RequestSend.ScheduledSend -> SlaveSchedulerC.RequestScheduledSend;
  DefaultScheduledSend = SlaveSchedulerC.DefaultScheduledSend;

  SlaveSchedulerC.AnnounceReceive -> AnnounceReceive;
  SlaveSchedulerC.RequestSend -> RequestSend;
  SlaveSchedulerC.ResponseReceive -> ResponseReceive;

}
