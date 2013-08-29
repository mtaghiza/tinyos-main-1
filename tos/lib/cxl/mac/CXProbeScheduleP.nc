
 #include "CXMac.h"
module CXProbeScheduleP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
  provides interface Init;
} implementation {

  //Defaults by role: global at 1/4 rate of router/subnet
  #if CX_BASESTATION == 1
  //basestation uses global/router only
  probe_schedule_t sched = { 
    .channel={128, 0, 64},
    .invFrequency={4, 0, 1},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #elif CX_ROUTER == 1
  //router uses all segments: no need to probe to own subnetwork,
  //though (will screw things up if two routers are on the same
  //channel).
  // N.B. This implies that leaf nodes will *not* store phoenix refs
  // from router (though router may store refs from leafs)
  probe_schedule_t sched = { 
    .channel={128, 0, 64},
    .invFrequency={4, 0, 1},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #else
  //leaf uses  global/subnetwork only
  probe_schedule_t sched = { 
    .channel={128, 0, 64},
    .invFrequency={4, 1, 0},
    .bw={2, 2, 2},
    .maxDepth={8,5,5}
  };
  #endif

  command error_t Init.init(){
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    call SettingsStorage.get(SS_KEY_PROBE_SCHEDULE, 
      &sched, sizeof(sched));
    //if this fails, we'll use defaults.
    return &sched;
  }
}
