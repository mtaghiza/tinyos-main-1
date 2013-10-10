
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
    .invFrequency={4, 1, 1},
    .bw={2, 2, 2},
    .maxDepth={2*CX_MAX_DEPTH,CX_MAX_DEPTH,CX_MAX_DEPTH}
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
    .maxDepth={2*CX_MAX_DEPTH,CX_MAX_DEPTH,CX_MAX_DEPTH}
  };
  #else
  //leaf uses  global/subnetwork only
  probe_schedule_t sched = { 
    .channel={128, 0, 64},
    .invFrequency={4, 1, 0},
    .bw={2, 2, 2},
    .maxDepth={2*CX_MAX_DEPTH,CX_MAX_DEPTH,CX_MAX_DEPTH}
  };
  #endif

  command error_t Init.init(){
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    //probe interval is in ms, wakeupLen is in 32k
    sched.wakeupLen[0] = (LPP_DEFAULT_PROBE_INTERVAL * 4UL * 8UL) << 5;
    sched.wakeupLen[1] = (LPP_DEFAULT_PROBE_INTERVAL * 1UL * 5UL) << 5;
    sched.wakeupLen[2] = (LPP_DEFAULT_PROBE_INTERVAL * 1UL * 5UL) << 5;
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    call SettingsStorage.get(SS_KEY_PROBE_SCHEDULE, 
      &sched, sizeof(sched));
    //if this fails, we'll use defaults.
    return &sched;
  }
}
