configuration TDMASchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
  
} implementation {
  #if TDMA_ROOT == 1 
  components RouterSchedulerC as TDMASchedulerP;
  #else 
  components LeafSchedulerC as TDMASchedulerP;
  #endif

  TDMARoutingSchedule = TDMASchedulerP.TDMARoutingSchedule;
  TDMAPhySchedule = TDMASchedulerP.TDMAPhySchedule;
  FrameStarted = TDMASchedulerP.FrameStarted;
  SplitControl = TDMASchedulerP.SplitControl;
  TDMASchedulerP.SubSplitControl = SubSplitControl;
}
