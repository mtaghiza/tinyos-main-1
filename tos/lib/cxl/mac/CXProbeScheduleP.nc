/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


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
//    .invFrequency={4, 1, 1},
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
//    .invFrequency={4, 0, 1},
    .bw={2, 2, 2},
    .maxDepth={2*CX_MAX_DEPTH, CX_MAX_DEPTH, CX_MAX_DEPTH}
  };
  #else
  //leaf uses  global/subnetwork only
  probe_schedule_t sched = { 
    .channel={128, 0, 64},
//    .invFrequency={4, 1, 0},
    .bw={2, 2, 2},
    .maxDepth={2*CX_MAX_DEPTH,CX_MAX_DEPTH, 0 }
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
