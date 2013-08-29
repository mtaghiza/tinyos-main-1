
 #include "CXMac.h"
module CXProbeScheduleStaticP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
  provides interface Init;
} implementation {
  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, 32, 64},
    .invFrequency={1, 1, 1},
    .bw={2, 2, 2},
    .maxDepth={5,5,5}
  };


  command error_t Init.init(){
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}

