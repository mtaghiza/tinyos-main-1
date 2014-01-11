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

 #include "CXTransport.h"
 #include "CXNetwork.h"

configuration CXTransportC{ 
  provides interface Send[uint8_t tproto]; 
  provides interface Receive[uint8_t tproto]; 

} implementation {
  components TDMASchedulerC;
  components CXNetworkC;
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components CXRoutingTableC;
  components SimpleFloodSchedulerC;
  
  Send[CX_TP_SIMPLE_FLOOD] = SimpleFloodSchedulerC.Send;
  Receive[CX_TP_SIMPLE_FLOOD] = SimpleFloodSchedulerC.Receive;
  SimpleFloodSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  SimpleFloodSchedulerC.AMPacketBody -> CXPacketStackC.AMPacketBody;
  SimpleFloodSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  SimpleFloodSchedulerC.CXPacketMetadata 
    -> CXPacketStackC.CXPacketMetadata;
  SimpleFloodSchedulerC.TDMARoutingSchedule 
    -> TDMASchedulerC.TDMARoutingSchedule;
  SimpleFloodSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_SIMPLE_FLOOD];
  SimpleFloodSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_SIMPLE_FLOOD];

  CXNetworkC.CXTransportSchedule[CX_TP_SIMPLE_FLOOD] 
    -> SimpleFloodSchedulerC.CXTransportSchedule;

#if INCLUDE_UNRELIABLE_BURST == 1
  components UnreliableBurstSchedulerC;
  UnreliableBurstSchedulerC.TDMARoutingSchedule ->
    TDMASchedulerC.TDMARoutingSchedule;
  UnreliableBurstSchedulerC.SlotStarted -> TDMASchedulerC.SlotStarted;

  UnreliableBurstSchedulerC.FloodSend 
    -> CXNetworkC.FloodSend[CX_TP_UNRELIABLE_BURST];
  UnreliableBurstSchedulerC.FloodReceive 
    -> CXNetworkC.FloodReceive[CX_TP_UNRELIABLE_BURST];

  #if INCLUDE_SCOPED_FLOOD == 1
  UnreliableBurstSchedulerC.ScopedFloodSend 
    -> CXNetworkC.ScopedFloodSend[CX_TP_UNRELIABLE_BURST];
  UnreliableBurstSchedulerC.ScopedFloodReceive 
    -> CXNetworkC.ScopedFloodReceive[CX_TP_UNRELIABLE_BURST];
  #endif

  UnreliableBurstSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  UnreliableBurstSchedulerC.AMPacketBody 
    -> CXPacketStackC.AMPacketBody;
  UnreliableBurstSchedulerC.CXPacketBody 
    -> CXPacketStackC.CXPacketBody;
  UnreliableBurstSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  UnreliableBurstSchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  UnreliableBurstSchedulerC.CXRoutingTable -> CXRoutingTableC;

  Send[CX_TP_UNRELIABLE_BURST] = UnreliableBurstSchedulerC.Send;
  Receive[CX_TP_UNRELIABLE_BURST] = UnreliableBurstSchedulerC.Receive;
  CXNetworkC.CXTransportSchedule[CX_TP_UNRELIABLE_BURST] 
    -> UnreliableBurstSchedulerC.CXTransportSchedule;
#endif

#if INCLUDE_RELIABLE_BURST == 1
  components ReliableBurstSchedulerC;
  ReliableBurstSchedulerC.TDMARoutingSchedule ->
    TDMASchedulerC.TDMARoutingSchedule;
  ReliableBurstSchedulerC.SlotStarted -> TDMASchedulerC.SlotStarted;

  ReliableBurstSchedulerC.ScopedFloodSend 
    -> CXNetworkC.ScopedFloodSend[CX_TP_RELIABLE_BURST];
  ReliableBurstSchedulerC.ScopedFloodReceive 
    -> CXNetworkC.ScopedFloodReceive[CX_TP_RELIABLE_BURST];

  ReliableBurstSchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  ReliableBurstSchedulerC.AMPacketBody 
    -> CXPacketStackC.AMPacketBody;
  ReliableBurstSchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  ReliableBurstSchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  Send[CX_TP_RELIABLE_BURST] = ReliableBurstSchedulerC.Send;
  Receive[CX_TP_RELIABLE_BURST] = ReliableBurstSchedulerC.Receive;

  CXNetworkC.CXTransportSchedule[CX_TP_RELIABLE_BURST] 
    -> ReliableBurstSchedulerC.CXTransportSchedule;
#endif
}
