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


 #include "CXScheduler.h"
configuration CXRouterSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet;
  provides interface SlotTiming;
} implementation {
  components CXRouterSchedulerUpperP;

  components CXMasterSchedulerP;
  components CXSlaveSchedulerP;

  components CXRouterSchedulerLowerP;

  components SlotSchedulerP;
  components CXNetworkC;
  components CXLinkC;

  SplitControl = CXRouterSchedulerUpperP;
  CXRequestQueue = CXRouterSchedulerUpperP;
  SlotTiming = SlotSchedulerP;

  CXRouterSchedulerUpperP.MasterCXRQ -> CXMasterSchedulerP;
  CXRouterSchedulerUpperP.SlaveCXRQ -> CXSlaveSchedulerP;
  
  CXMasterSchedulerP.SubCXRQ -> CXRouterSchedulerLowerP.MasterCXRQ;
  CXSlaveSchedulerP.SubCXRQ -> CXRouterSchedulerLowerP.SlaveCXRQ;

  CXRouterSchedulerLowerP.CXRequestQueue -> SlotSchedulerP.CXRequestQueue;
  CXRouterSchedulerLowerP.SplitControl -> CXNetworkC.SplitControl;
  SlotSchedulerP.SubCXRQ -> CXNetworkC;
  SlotSchedulerP.ActivityNotify -> CXNetworkC;
  SlotSchedulerP.RadioStateLog -> CXLinkC;
  
  CXRouterSchedulerLowerP.GetSlaveMode -> CXRouterSchedulerUpperP;

  //packet stack
  components CXSchedulerPacketC;
  components CXLinkPacketC;
  components CXPacketMetadataC;
  components CXNetworkPacketC;

  Packet = CXSchedulerPacketC;

  components MainC;
  components RandomC;

  //slave region
  CXSlaveSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXSlaveSchedulerP.ScheduleParams -> SlotSchedulerP;
  CXSlaveSchedulerP.Packet -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  CXSlaveSchedulerP.CXLinkPacket -> CXLinkPacketC;

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


  components CXRoutingTableC;
  CXSlaveSchedulerP.RoutingTable -> CXRoutingTableC;

  components new ScheduledAMSenderC(AM_CX_REQUEST_MSG);
  CXSlaveSchedulerP.RequestSend -> ScheduledAMSenderC;

  CXSlaveSchedulerP.Random -> RandomC;

  components CXAMAddressC;
  CXSlaveSchedulerP.ActiveMessageAddress -> CXAMAddressC;

  components StateDumpC;
  CXSlaveSchedulerP.StateDump -> StateDumpC;
  SlotSchedulerP.StateDump -> StateDumpC;
  CXSlaveSchedulerP.RadioStateLog -> CXLinkC;

  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkPacketC;

  //master region
  CXMasterSchedulerP.RadioStateLog -> CXLinkC;

  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXNetworkPacket -> CXNetworkC;
  CXMasterSchedulerP.CXLinkPacket -> CXLinkPacketC;
  CXMasterSchedulerP.CXPacketMetadata -> CXPacketMetadataC;
  CXMasterSchedulerP.SkewCorrection -> SkewCorrectionC;
  CXMasterSchedulerP.Boot -> MainC.Boot;
  CXMasterSchedulerP.Random -> RandomC;
  CXMasterSchedulerP.ActiveMessageAddress -> CXAMAddressC;
  CXMasterSchedulerP.RoutingTable -> CXRoutingTableC;

  components new ScheduledAMSenderC(AM_CX_SCHEDULE_MSG) as ScheduleSenderC;
  CXMasterSchedulerP.ScheduleSend -> ScheduleSenderC;
  components new ScheduledAMSenderC(AM_CX_ASSIGNMENT_MSG) as AssignmentSenderC;
  CXMasterSchedulerP.AssignmentSend -> AssignmentSenderC;

  components new AMReceiverC(AM_CX_REQUEST_MSG);
  CXMasterSchedulerP.RequestReceive -> AMReceiverC;

  CXMasterSchedulerP.ScheduleParams -> SlotSchedulerP;

  CXMasterSchedulerP.SubSplitControl -> CXRouterSchedulerLowerP.MasterSplitControl;
  CXSlaveSchedulerP.SubSplitControl -> CXRouterSchedulerLowerP.SlaveSplitControl;
  CXRouterSchedulerUpperP.SlaveSplitControl -> CXSlaveSchedulerP.SplitControl;
  CXRouterSchedulerUpperP.MasterSplitControl -> CXMasterSchedulerP.SplitControl;

}
