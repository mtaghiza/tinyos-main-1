
 #include "CXScheduler.h"
configuration CXSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  provides interface SlotTiming;
} implementation {
  #if CX_MASTER == 1
  components CXMasterSchedulerC as CXScheduler;
  #else
  components CXSlaveSchedulerC as CXScheduler;
  #endif
  
  CXRequestQueue = CXScheduler;
  SplitControl = CXScheduler;
  Packet = CXScheduler;
  SlotTiming = CXScheduler;
}
