 #include "schedule.h"
configuration LeafSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
  provides interface SlotStarted;
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
  components new CXAMSenderC(AM_ID_LEAF_REQUEST, CX_TP_SIMPLE_FLOOD)
    as RequestSend;
  components new AMReceiverC(AM_ID_LEAF_RESPONSE) as ResponseReceive;

  SlaveSchedulerC.AnnounceReceive -> AnnounceReceive;
  SlaveSchedulerC.RequestSend -> RequestSend;
  SlaveSchedulerC.ResponseReceive -> ResponseReceive;

}
