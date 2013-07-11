
 #include "CXMac.h"
module CXProbeScheduleP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
} implementation {
  //Defaults by role: global at 1/4 rate of router/subnet
  #if CX_BASESTATION == 1
  //basestation uses global/router only
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 0, 1}
  };
  #elif CX_ROUTER == 1
  //router uses all segments
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 1, 1}
  };
  #else
  //leaf uses  global/subnetwork only
  probe_schedule_t sched = { 
    .channel={0, 32, 64},
    .invFrequency={4, 1, 0}
  };
  #endif

  command probe_schedule_t* Get.get(){
    call SettingsStorage.get(SS_KEY_PROBE_SCHEDULE, 
      &sched, sizeof(sched));
    //if this fails, we'll use defaults.
    return &sched;
  }
}
