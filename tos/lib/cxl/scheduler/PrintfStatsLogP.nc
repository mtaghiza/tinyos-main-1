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


 #include "CXLinkDebug.h"
 #include "CXLink.h"
module PrintfStatsLogP{
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;
  uses interface Packet;
} implementation {
  cx_link_stats_t lastStats;
  uint16_t lastWakeupNum;
  int16_t lastSlotNum;
  uint8_t lastSlotRole;
  
  task void logStats0();
  task void logStats1();
  task void logStats2();
  task void logStats3();
  task void logStats4();
  task void logStats5();
  task void logStats6();
  task void logStats7();
  task void logStats8();

  task void logStats0(){
    cinfo(STATS_RADIO, "SS 0 %u %i\r\n",
      lastWakeupNum, lastSlotNum);
    post logStats1();
  }
  task void logStats1(){
    cinfo(STATS_RADIO, "SS 1 %lu\r\n",
      lastStats.total);
    post logStats2();
  }

  task void logStats2(){
    cinfo(STATS_RADIO, "SS 2 %lu\r\n",
      lastStats.off);
    post logStats3();
  }

  task void logStats3(){
    cinfo(STATS_RADIO, "SS 3 %lu\r\n",
      lastStats.idle);
    post logStats4();
  }

  task void logStats4(){
    cinfo(STATS_RADIO, "SS 4 %lu\r\n",
      lastStats.sleep);
    post logStats5();
  }
  task void logStats5(){
    cinfo(STATS_RADIO, "SS 5 %lu\r\n",
      lastStats.rx);
    post logStats6();
  }
  task void logStats6(){
    cinfo(STATS_RADIO, "SS 6 %lu\r\n",
      lastStats.tx);
    post logStats7();
  }
  task void logStats7(){
    cinfo(STATS_RADIO, "SS 7 %lu\r\n",
      lastStats.fstxon);
    post logStats8();
  }
  task void logStats8(){
    cinfo(STATS_RADIO, "SS 8 %u\r\n",
      lastSlotRole);
  }

  command void StatsLog.logSlotStats(cx_link_stats_t stats, 
      uint16_t wakeupNum, int16_t slotNum, 
      uint8_t slotRole){
    lastStats = stats;
    lastWakeupNum = wakeupNum;
    lastSlotNum = slotNum;
    lastSlotRole = slotRole;
    post logStats0();
//    cinfo(STATS_RADIO, "SS %u %i %lu %lu %lu %lu %lu %lu %lu %u\r\n",
//      wakeupNum,
//      slotNum,
//      stats.total,
//      stats.off,
//      stats.idle,
//      stats.sleep,
//      stats.rx,
//      stats.tx,
//      stats.fstxon, 
//      slotRole); //e.g. owner, origin, forwarder, slept
//    cinfo(STATS_RADIO, "SS %u %i %lu %lu %lu %u\r\n",
//      wakeupNum, slotNum, stats.total,
//      stats.off + stats.sleep + stats.idle,
//      stats.rx + stats.tx + stats.fstxon,
//      slotRole);
  }

  command void StatsLog.logReception(message_t* msg,
      uint16_t wakeupNum, int16_t slotNum){
    cinfo(STATS, "R %u %i %u %u %u\r\n",
      wakeupNum,
      slotNum,
      call CXLinkPacket.source(msg),
      call CXLinkPacket.getSn(msg),
      call CXLinkPacket.rxHopCount(msg));
  }

  command void StatsLog.logTransmission(message_t* msg, 
      uint16_t wakeupNum, int16_t slotNum){
    cinfo(STATS, "T %u %i %u %u %u %u\r\n",
      wakeupNum,
      slotNum, 
      call CXLinkPacket.getSn(msg),
      call Packet.payloadLength(msg),
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));
    //additional info: status neeeds to indicate DP
    if (call CXMacPacket.getMacType(msg) == CXM_STATUS){
      cx_status_t* status = (cx_status_t*) (call Packet.getPayload(msg, sizeof(cx_status_t)));
      cinfo(STATS, "S %u %i %u %u\r\n", 
        wakeupNum,
        slotNum, 
        call CXLinkPacket.getSn(msg),
        status->dataPending);
    }else if (call CXMacPacket.getMacType(msg) == CXM_EOS){
      cx_eos_t* eos = (cx_eos_t*) (call Packet.getPayload(msg,
        sizeof(cx_eos_t)));
      cinfo(STATS, "E %u %i %u %u\r\n", 
        wakeupNum,
        slotNum, 
        call CXLinkPacket.getSn(msg),
        eos->dataPending);
    }
  }

  command void StatsLog.flush(){
    cflushinfo(STATS);
  }
  
}
