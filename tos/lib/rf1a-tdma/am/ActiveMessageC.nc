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

configuration ActiveMessageC {
  provides interface SplitControl;
  
  provides interface Packet;
  provides interface Rf1aPacket;
  provides interface CXPacket;
  provides interface AMPacket;

  provides interface CXPacketMetadata;

  //Separate paths for each transport protocol
  provides interface Send[uint8_t tproto];

  //at receiver: no distinction
  provides interface Receive[am_id_t id];
  provides interface ReceiveNotify;

  provides interface PacketAcknowledgements;
  provides interface TDMARoutingSchedule;
  provides interface SlotStarted;
  provides interface ScheduledSend as DefaultScheduledSend;

} implementation {
  components CXPacketStackC;

  components CXTDMAPhysicalC;
  components CXNetworkC;
  components CXTransportC;
  components CXRoutingTableC;

  components CombineReceiveP;
  components new QueueC(message_t*, CX_MESSAGE_POOL_SIZE);
  components new PoolC(message_t, CX_MESSAGE_POOL_SIZE);

  CombineReceiveP.SubReceive ->
    CXTransportC.Receive;
  CombineReceiveP.CXPacket -> CXPacketStackC.CXPacket;
  CombineReceiveP.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CombineReceiveP.Rf1aPacket -> CXPacketStackC.Rf1aPacket;
  CombineReceiveP.AMPacket -> CXPacketStackC.AMPacket;
  CombineReceiveP.AMPacketBody -> CXPacketStackC.AMPacketBody;
  CombineReceiveP.Queue -> QueueC;
  CombineReceiveP.Pool -> PoolC;

  Receive = CombineReceiveP.Receive;
  ReceiveNotify = CombineReceiveP.ReceiveNotify;

  //this component is responsible for:
  // - receiving/distributing schedule-related packets
  // - instructing the phy layer how to configure itself
  // - telling the various routing methods when they are allowed to
  //   send.
  components TDMASchedulerC;


  //Scheduler: should sit above transport layer. So it should be
  //dealing with AM packets (using CX header as needed)
  TDMASchedulerC.SubSplitControl -> CXTDMAPhysicalC;

  TDMASchedulerC.TDMAPhySchedule -> CXTDMAPhysicalC;
  TDMASchedulerC.FrameStarted -> CXTDMAPhysicalC;

  SplitControl = TDMASchedulerC.SplitControl;
  SlotStarted = TDMASchedulerC.SlotStarted;
  TDMARoutingSchedule = TDMASchedulerC.TDMARoutingSchedule;
  DefaultScheduledSend = TDMASchedulerC.DefaultScheduledSend;

  AMPacket = CXPacketStackC.AMPacket;
  CXPacket = CXPacketStackC.CXPacket;
  CXPacketMetadata = CXPacketStackC.CXPacketMetadata;
  Packet = CXPacketStackC.AMPacketBody;
  Rf1aPacket = CXPacketStackC.Rf1aPacket;
  PacketAcknowledgements = CXPacketStackC.PacketAcknowledgements;

  Send = CXTransportC.Send;

}
