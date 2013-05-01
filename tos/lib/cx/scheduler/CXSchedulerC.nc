
 #include "CXScheduler.h"
configuration CXSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  provides interface SlotTiming;
} implementation {
  #if CX_STATIC_SCHEDULE == 1
    #warning "Using static scheduler: TEST ONLY"
    #if CX_MASTER == 1
    components CXMasterSchedulerStaticC as CXScheduler;
    #else
    components CXSlaveSchedulerStaticC as CXScheduler;
    #endif
  #else
    #if CX_MASTER == 1
    components CXMasterSchedulerC as CXScheduler;
    #else
    components CXSlaveSchedulerC as CXScheduler;
    #endif

  #endif
  
  CXRequestQueue = CXScheduler;
  SplitControl = CXScheduler;
  Packet = CXScheduler;
  SlotTiming = CXScheduler;
}
