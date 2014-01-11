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

 #include "CXNetwork.h"
configuration CXNetworkC {
  provides interface Send as FloodSend[uint8_t t];
  provides interface Receive as FloodReceive[uint8_t t];

  #if INCLUDE_SCOPED_FLOOD == 1
  provides interface Send as ScopedFloodSend[uint8_t t];
  provides interface Receive as ScopedFloodReceive[uint8_t t];
  #endif

  uses interface CXTransportSchedule[uint8_t tProto];

} implementation {
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components TDMASchedulerC;

  components CXTDMADispatchC;
  CXTDMADispatchC.SubCXTDMA -> CXTDMAPhysicalC;
  CXTDMADispatchC.CXPacket -> CXPacketStackC.CXPacket;
  CXTDMADispatchC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  components CXRoutingTableC;

  components CXFloodC;
  CXFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_FLOOD];
  CXFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_FLOOD];
  CXFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXFloodC.CXTransportSchedule = CXTransportSchedule;
  CXFloodC.CXRoutingTable -> CXRoutingTableC;

  FloodSend = CXFloodC;
  FloodReceive = CXFloodC;

  #if INCLUDE_SCOPED_FLOOD
  components CXScopedFloodC;
  CXScopedFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXScopedFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXScopedFloodC.AMPacket -> CXPacketStackC.AMPacket;
  CXScopedFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXScopedFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXScopedFloodC.CXTransportSchedule = CXTransportSchedule;
  CXScopedFloodC.CXRoutingTable -> CXRoutingTableC;

  ScopedFloodSend = CXScopedFloodC;
  ScopedFloodReceive = CXScopedFloodC;
  #endif




}
