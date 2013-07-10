
 #include "CXMac.h"
module CXProbeScheduleP {
  provides interface Get<probe_schedule_t*>;
  uses interface Boot;
} implementation {
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={1, 2, 4}
  };

  event void Boot.booted(){
    //TODO: read from settings storage
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}
