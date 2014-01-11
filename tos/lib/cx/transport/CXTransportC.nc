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

configuration CXTransportC {
  provides interface SplitControl;
  provides interface Packet;

  provides interface Send as ScheduledSend;

  provides interface Send as BroadcastSend;
  provides interface Receive as BroadcastReceive;

  provides interface Send as UnicastSend;
  provides interface Receive as UnicastReceive;
} implementation {
  
  //When packets received, push them to relevant subprotocol
  components CXTransportDispatchP;
  components CXSchedulerC;

  CXTransportDispatchP.SubCXRQ -> CXSchedulerC;
  //needed so that we can notify sub-protocols when to put in their RX
  //requests
  CXTransportDispatchP.SubSplitControl -> CXSchedulerC;
  SplitControl = CXTransportDispatchP;

  //hook up sub-protocols
  components FloodBurstP;
  components RRBurstP;
  components ScheduledTXP;
  BroadcastSend = FloodBurstP;
  BroadcastReceive = FloodBurstP;
  UnicastSend = RRBurstP;
  UnicastReceive = RRBurstP;
  ScheduledSend = ScheduledTXP;

  ScheduledTXP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_SCHEDULED];
  FloodBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_FLOOD_BURST];
  RRBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_RR_BURST];

  FloodBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_FLOOD_BURST];
  RRBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_RR_BURST];

  FloodBurstP.SlotTiming -> CXSchedulerC;
  RRBurstP.SlotTiming -> CXSchedulerC;

  CXTransportDispatchP.RequestPending[CX_TP_FLOOD_BURST] 
    -> FloodBurstP.RequestPending;
  CXTransportDispatchP.RequestPending[CX_TP_RR_BURST] 
    -> RRBurstP.RequestPending;
  
  components CXTransportPacketC;
  Packet = CXTransportPacketC;

  components CXPacketMetadataC;
  ScheduledTXP.CXPacketMetadata -> CXPacketMetadataC;
  FloodBurstP.CXPacketMetadata -> CXPacketMetadataC;

  CXTransportDispatchP.CXPacketMetadata -> CXPacketMetadataC;
  CXTransportDispatchP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.CXTransportPacket -> CXTransportPacketC;
  RRBurstP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.Packet -> CXTransportPacketC;
  RRBurstP.Packet -> CXTransportPacketC;

  components ActiveMessageC;
  ScheduledTXP.AMPacket -> ActiveMessageC;
  ScheduledTXP.CXTransportPacket -> CXTransportPacketC;

  components CXRoutingTableC;
  FloodBurstP.RoutingTable -> CXRoutingTableC;
  FloodBurstP.AMPacket -> ActiveMessageC;

  RRBurstP.RoutingTable -> CXRoutingTableC;
  RRBurstP.AMPacket -> ActiveMessageC;

  components CXNetworkPacketC;
  RRBurstP.CXNetworkPacket -> CXNetworkPacketC;

  components new ScheduledAMSenderC(AM_CX_RR_ACK_MSG) as AckSenderC;
  RRBurstP.AckSend -> AckSenderC;
  RRBurstP.AckPacket -> AckSenderC;

//  components new AMSnoopingReceiverC(AM_CX_RR_ACK_MSG);
//  RRBurstP.AckReceive -> AMSnoopingReceiverC;

  CXTransportDispatchP.AMPacket -> ActiveMessageC;

  FloodBurstP.GetLastBroadcast 
    -> CXTransportDispatchP.GetLastBroadcast;

  components CXAMAddressC;
  FloodBurstP.ActiveMessageAddress -> CXAMAddressC;
  RRBurstP.ActiveMessageAddress -> CXAMAddressC;

  components new TimerMilliC() as FBTimer;
  components new TimerMilliC() as RRBTimer;
  FloodBurstP.RetryTimer -> FBTimer;
  RRBurstP.RetryTimer -> RRBTimer;

  components StateDumpC;
  FloodBurstP.StateDump -> StateDumpC;
  RRBurstP.StateDump -> StateDumpC;
}
