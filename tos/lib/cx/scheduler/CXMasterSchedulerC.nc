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
 *  master-specific role scheduler.
 *
 *  When started, this will periodically send out schedule
 *  announcements.
 **/
 #include "CXScheduler.h"
configuration CXMasterSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet;
  provides interface SlotTiming;
} implementation {
  //CX stack components
  components CXMasterSchedulerP;
  components SlotSchedulerP;
  components CXNetworkC;
  
  //for radio logging
  components CXLinkC;

  //CX Stack wiring
  SplitControl = CXMasterSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;

  CXMasterSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXMasterSchedulerP.SubSplitControl -> CXNetworkC;
  CXMasterSchedulerP.RadioStateLog -> CXLinkC;

  SlotSchedulerP.RadioStateLog -> CXLinkC;
  SlotSchedulerP.SubCXRQ -> CXNetworkC;
  SlotSchedulerP.ActivityNotify -> CXNetworkC.ActivityNotify;
  
  //communication between role-specific and role-agnostic code
  CXMasterSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXMasterSchedulerP.ScheduleParams -> SlotSchedulerP.ScheduleParams;

  //packet stack
  components CXSchedulerPacketC;
  components CXLinkPacketC;
  components CXPacketMetadataC;

  Packet = CXSchedulerPacketC;
  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXNetworkPacket -> CXNetworkC;
  CXMasterSchedulerP.CXLinkPacket -> CXLinkPacketC;

  CXMasterSchedulerP.CXPacketMetadata -> CXPacketMetadataC;

  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkC;

  //Skew correction 
  #if CX_ENABLE_SKEW_CORRECTION
  components SkewCorrectionC;
  #else
  #warning "Disabled skew correction."
  components DummySkewCorrectionC as SkewCorrectionC;
  #endif
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  CXMasterSchedulerP.SkewCorrection -> SkewCorrectionC;

  //Role scheduler internals
  components MainC;
  components RandomC;
  CXMasterSchedulerP.Boot -> MainC.Boot;
  CXMasterSchedulerP.Random -> RandomC;

  components new ScheduledAMSenderC(AM_CX_SCHEDULE_MSG) as ScheduleSenderC;
  CXMasterSchedulerP.ScheduleSend -> ScheduleSenderC;

  SlotTiming = SlotSchedulerP;

  components CXRoutingTableC;
  CXMasterSchedulerP.RoutingTable -> CXRoutingTableC;

  components new ScheduledAMSenderC(AM_CX_ASSIGNMENT_MSG) as AssignmentSenderC;
  CXMasterSchedulerP.AssignmentSend -> AssignmentSenderC;

  components new AMReceiverC(AM_CX_REQUEST_MSG);
  CXMasterSchedulerP.RequestReceive -> AMReceiverC;
  
  components CXAMAddressC;
  CXMasterSchedulerP.ActiveMessageAddress -> CXAMAddressC;

  components StateDumpC;
  CXMasterSchedulerP.StateDump -> StateDumpC;
  SlotSchedulerP.StateDump -> StateDumpC;
}
