
 #include "CXMac.h"
module CXProbeScheduleStaticP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
  provides interface Init;
} implementation {
  #if CX_BASESTATION == 1
  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, SUBNETWORK_CHANNEL, ROUTER_CHANNEL},
    .invFrequency={1, 0, 1},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #elif CX_ROUTER == 1
  //argh, I wish that invFrequency could be 0 for Subnetwork channel,
  //but that breaks the wakeup len logic.
  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, SUBNETWORK_CHANNEL, ROUTER_CHANNEL},
    .invFrequency={1, 1, 1},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #else
  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, SUBNETWORK_CHANNEL, ROUTER_CHANNEL},
    .invFrequency={1, 1, 0},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #endif

  command error_t Init.init(){
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}

