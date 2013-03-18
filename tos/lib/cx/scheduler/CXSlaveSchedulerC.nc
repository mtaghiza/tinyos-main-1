configuration CXSlaveSchedulerC{
  provides interface SplitControl;
  provides interface CXScheduler;
} implementation {
  components CXSlaveSchedulerP;

  components CXTransportC;

  CXSlaveSchedulerP.SubSplitControl -> CXTransportC;
  SplitControl = CXSlaveSchedulerP;
  
  CXSlaveScheduler = CXSlaveSchedulerP;
}
