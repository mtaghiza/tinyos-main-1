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

configuration SlotSchedulerC{

  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  uses interface Pool<message_t>;

  uses interface SlotController[uint8_t ns];

  provides interface Neighborhood;
  provides interface DownloadNotify[uint8_t ns];

  uses interface Get<uint32_t> as PushCookie;
  uses interface Get<uint32_t> as WriteCookie;
  uses interface Get<uint32_t> as MissingLength;
} implementation {
  components CXWakeupC;
  components SlotSchedulerP;

  SlotSchedulerP.PushCookie = PushCookie;
  SlotSchedulerP.WriteCookie = WriteCookie;
  SlotSchedulerP.MissingLength = MissingLength;
  components new Timer32khzC() as SlotTimer;
  components new Timer32khzC() as FrameTimer;
  components LocalTimeMilliC;
  SlotSchedulerP.SlotTimer -> SlotTimer;
  SlotSchedulerP.FrameTimer -> FrameTimer;
  SlotSchedulerP.LocalTime -> LocalTimeMilliC;

  Send = SlotSchedulerP.Send;
  Receive = SlotSchedulerP.Receive;
  SplitControl = CXWakeupC.SplitControl;
  SlotSchedulerP.Pool = Pool;
  CXWakeupC.Pool = Pool;
  SlotSchedulerP.SlotController = SlotController;
  
  SlotSchedulerP.CXLink -> CXWakeupC.CXLink;
  SlotSchedulerP.LppControl -> CXWakeupC.LppControl;
  SlotSchedulerP.CXMacPacket -> CXWakeupC.CXMacPacket;
  SlotSchedulerP.CXLinkPacket -> CXWakeupC.CXLinkPacket;
  SlotSchedulerP.Packet -> CXWakeupC.Packet;
  SlotSchedulerP.SubSend -> CXWakeupC.Send;
  SlotSchedulerP.SubReceive -> CXWakeupC.Receive;

  components NeighborhoodC;
  SlotSchedulerP.Neighborhood -> NeighborhoodC;
  Neighborhood = NeighborhoodC;
  NeighborhoodC.LppProbeSniffer -> CXWakeupC;
  //points to body of mac
  NeighborhoodC.Packet -> CXWakeupC.Packet;
  NeighborhoodC.CXLinkPacket -> CXWakeupC.CXLinkPacket;

  Packet = CXWakeupC.Packet;

  components CXAMAddressC;
  SlotSchedulerP.ActiveMessageAddress -> CXAMAddressC;

  components CXRoutingTableC;
  SlotSchedulerP.RoutingTable -> CXRoutingTableC;

  components RebootCounterC;
  SlotSchedulerP.RebootCounter -> RebootCounterC;

  components CXProbeScheduleC;
  SlotSchedulerP.ProbeSchedule -> CXProbeScheduleC.Get;

  components StateDumpC;
  SlotSchedulerP.StateDump -> StateDumpC;

  #ifndef AM_STATS_LOG
  #define AM_STATS_LOG 0
  #endif
  #ifndef PRINTF_STATS_LOG
  #define PRINTF_STATS_LOG 0
  #endif

  #if AM_STATS_LOG == 1
  components SerialStartC;
  components AMStatsLogC as StatsLog;

  StatsLog.CXLinkPacket -> CXWakeupC.CXLinkPacket;
  StatsLog.CXMacPacket -> CXWakeupC.CXMacPacket;
  StatsLog.Packet -> CXWakeupC.Packet;
  SlotSchedulerP.StatsLog -> StatsLog;

  #elif PRINTF_STATS_LOG == 1

  components PrintfStatsLogC as StatsLog;
  StatsLog.CXLinkPacket -> CXWakeupC.CXLinkPacket;
  StatsLog.CXMacPacket -> CXWakeupC.CXMacPacket;
  StatsLog.Packet -> CXWakeupC.Packet;
  SlotSchedulerP.StatsLog -> StatsLog;
  #endif

  components SettingsStorageC;
  SlotSchedulerP.SettingsStorage -> SettingsStorageC;

  DownloadNotify = SlotSchedulerP;
}
