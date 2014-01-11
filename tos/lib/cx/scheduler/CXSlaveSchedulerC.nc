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

/**
 *  Wiring for scheduler portion of the CX stack. Includes
 *  role-agnostic SlotScheduler (wake up/skew-correct at every slot
 *  start, sleep during slots when no activity detected) and
 *  slave-specific role scheduler.
 *
 *  When started, this will listen for schedule announcements and join
 *  the schedule.
 **/
 #include "CXScheduler.h"
configuration CXSlaveSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  provides interface SlotTiming;
} implementation {
  //CX stack components
  components CXSlaveSchedulerP;
  components SlotSchedulerP;
  components CXNetworkC;
  //for radio logging
  components CXLinkC;
  
  //CX Stack wiring
  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXSlaveSchedulerP;

  CXSlaveSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXSlaveSchedulerP.SubSplitControl -> CXNetworkC;
  CXSlaveSchedulerP.RadioStateLog -> CXLinkC;

  SlotSchedulerP.RadioStateLog -> CXLinkC;
  SlotSchedulerP.ActivityNotify -> CXNetworkC.ActivityNotify;
  SlotSchedulerP.SubCXRQ -> CXNetworkC;
    
  //communication between role-specific and role-agnostic code
  CXSlaveSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXSlaveSchedulerP.ScheduleParams -> SlotSchedulerP;

  //packet stack
  components CXSchedulerPacketC;
  components CXNetworkPacketC;
  components CXLinkPacketC;

  Packet = CXSchedulerPacketC;
  CXSlaveSchedulerP.Packet -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  CXSlaveSchedulerP.CXLinkPacket -> CXLinkPacketC;

  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  
  //skew correction
  #if CX_ENABLE_SKEW_CORRECTION == 1
  components SkewCorrectionC;
  #else
  #warning "Disabled skew correction."
  components DummySkewCorrectionC as SkewCorrectionC;
  #endif
  CXSlaveSchedulerP.SkewCorrection -> SkewCorrectionC;
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  
  components new AMReceiverC(AM_CX_SCHEDULE_MSG) 
    as ScheduleReceive;
  CXSlaveSchedulerP.ScheduleReceive -> ScheduleReceive;

  components new AMReceiverC(AM_CX_ASSIGNMENT_MSG) 
    as AssignmentReceive;
  CXSlaveSchedulerP.AssignmentReceive -> AssignmentReceive;

  SlotTiming = SlotSchedulerP;

  components CXRoutingTableC;
  CXSlaveSchedulerP.RoutingTable -> CXRoutingTableC;

  components new ScheduledAMSenderC(AM_CX_REQUEST_MSG);
  CXSlaveSchedulerP.RequestSend -> ScheduledAMSenderC;

  components RandomC;
  CXSlaveSchedulerP.Random -> RandomC;

  components CXAMAddressC;
  CXSlaveSchedulerP.ActiveMessageAddress -> CXAMAddressC;

  components StateDumpC;
  CXSlaveSchedulerP.StateDump -> StateDumpC;
  SlotSchedulerP.StateDump -> StateDumpC;
}
