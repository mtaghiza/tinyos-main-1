 #include "schedule.h"
configuration LeafSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
} implementation{
  components SlaveSchedulerC;
  components CXTransportC;
  
  SlaveSchedulerC.FrameStarted = FrameStarted;
  SlaveSchedulerC.TDMAPhySchedule = TDMAPhySchedule;

  TDMARoutingSchedule = SlaveSchedulerC;
  SplitControl = SlaveSchedulerC.SplitControl;
  SlaveSchedulerC.SubSplitControl = SubSplitControl;
  SlaveSchedulerC.AnnounceReceive ->
    CXTransportC.SimpleFloodReceive[AM_ID_LEAF_SCHEDULE];
  SlaveSchedulerC.RequestSend ->
    CXTransportC.SimpleFloodSend[AM_ID_LEAF_REQUEST];
  SlaveSchedulerC.ResponseReceive -> 
    CXTransportC.SimpleFloodReceive[AM_ID_LEAF_RESPONSE];

}
