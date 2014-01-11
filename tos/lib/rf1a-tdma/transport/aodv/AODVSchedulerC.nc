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

configuration AODVSchedulerC{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule as SubTDMARoutingSchedule;
  uses interface FrameStarted;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet as AMPacketBody;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;

  uses interface CXRoutingTable;
} implementation {
  components AODVSchedulerP;

  CXTransportSchedule = AODVSchedulerP.CXTransportSchedule;
  AMSend = AODVSchedulerP.AMSend;
  Receive = AODVSchedulerP.Receive;
  AODVSchedulerP.SubTDMARoutingSchedule = SubTDMARoutingSchedule;
  AODVSchedulerP.FloodSend = FloodSend;
  AODVSchedulerP.FloodReceive = FloodReceive;
  AODVSchedulerP.ScopedFloodSend = ScopedFloodSend;
  AODVSchedulerP.ScopedFloodReceive = ScopedFloodReceive;
  AODVSchedulerP.AMPacket = AMPacket;
  AODVSchedulerP.CXPacket = CXPacket;
  AODVSchedulerP.CXPacketMetadata = CXPacketMetadata;
  AODVSchedulerP.AMPacketBody = AMPacketBody;
  AODVSchedulerP.Rf1aPacket = Rf1aPacket;
  AODVSchedulerP.Ieee154Packet = Ieee154Packet;

  AODVSchedulerP.CXRoutingTable = CXRoutingTable;
  AODVSchedulerP.FrameStarted = FrameStarted;
}
