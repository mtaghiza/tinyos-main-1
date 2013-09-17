
 #include "CXMac.h"
module CXProbeScheduleStaticP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
  provides interface Init;
} implementation {

  #if CX_BASESTATION == 1
  #define IF_G  1
  //to facilitate single-tier download
  #define IF_SN 1
  #define IF_R  1
  #elif CX_ROUTER == 1
  #define IF_G  1
  #define IF_SN 1
  #define IF_R  1
  #else
  #define IF_G  1
  #define IF_SN 1
  #define IF_R  0
  #endif

  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, SUBNETWORK_CHANNEL, ROUTER_CHANNEL},
    .invFrequency={IF_G, IF_SN, IF_R},
    .bw={STATIC_BW, STATIC_BW, STATIC_BW},
    .maxDepth={CX_MAX_DEPTH*2, CX_MAX_DEPTH, CX_MAX_DEPTH}
  };

  command error_t Init.init(){
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[0] = 32*CX_MAX_DEPTH*2 * IF_G * LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[1] = 32*CX_MAX_DEPTH*1 * IF_SN * LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[2] = 32*CX_MAX_DEPTH*1 * IF_R  * LPP_DEFAULT_PROBE_INTERVAL;
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}

