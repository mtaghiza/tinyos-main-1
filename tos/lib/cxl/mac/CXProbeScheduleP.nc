
 #include "CXMac.h"
module CXProbeScheduleP {
  provides interface Get<probe_schedule_t*>;
  uses interface Boot;
} implementation {
  #if CX_BASESTATION == 1
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 0, 1}
  };
  #elif CX_ROUTER == 1
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 1, 1}
  };
  #else
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 1, 0}
  };
  #endif

  event void Boot.booted(){
    //TODO: read from settings storage
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}
