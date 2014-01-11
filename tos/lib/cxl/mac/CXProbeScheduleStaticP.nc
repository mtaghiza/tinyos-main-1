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
module CXProbeScheduleStaticP {
  provides interface Get<probe_schedule_t*>;
  uses interface SettingsStorage;
  provides interface Init;
} implementation {

  #if CX_BASESTATION == 1
  #define MD_G  1
  //to facilitate single-tier download
  #define MD_SN 1
  #define MD_R  1
  #elif CX_ROUTER == 1
  #define MD_G  1
  #define MD_SN 1
  #define MD_R  1
  #else
  #define MD_G  1
  #define MD_SN 1
  #define MD_R  0
  #endif

  probe_schedule_t sched = { 
    .channel={GLOBAL_CHANNEL, SUBNETWORK_CHANNEL, ROUTER_CHANNEL},
//    .invFrequency={IF_G, IF_SN, IF_R},
    .bw={STATIC_BW, STATIC_BW, STATIC_BW},
    .maxDepth={MD_G*CX_MAX_DEPTH*2, MD_SN*CX_MAX_DEPTH, MD_R*CX_MAX_DEPTH}
  };

  command error_t Init.init(){
//    uint8_t i;
    sched.probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[0] = 32*CX_MAX_DEPTH*2 * MD_G * LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[1] = 32*CX_MAX_DEPTH*1 * MD_SN * LPP_DEFAULT_PROBE_INTERVAL;
    sched.wakeupLen[2] = 32*CX_MAX_DEPTH*1 * MD_R  * LPP_DEFAULT_PROBE_INTERVAL;
//    for (i =0; i <= 2; i++){
//      printf("Segment %u chan %u if %u bw %u md %u wu %lu\r\n",
//        i, sched.channel[i], sched.invFrequency[i], sched.bw[i],
//        sched.maxDepth[i], sched.wakeupLen[i]);
//    }
    return SUCCESS;
  }

  command probe_schedule_t* Get.get(){
    return &sched;
  }
}

