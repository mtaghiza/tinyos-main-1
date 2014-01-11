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

configuration TDMASchedulerC{
  provides interface SplitControl;
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface SplitControl as SubSplitControl;


  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface CXRoutingTable;
  uses interface FrameStarted;

} implementation {
  components CXTransportC;
  #if TDMA_ROOT == 1
  #warning compiling as TDMA root.
  components RootSchedulerP as TDMASchedulerP;
  #else
  components NonRootSchedulerP as TDMASchedulerP;
  #endif
  
  SplitControl = TDMASchedulerP.SplitControl; 

  TDMASchedulerP.SubSplitControl = SubSplitControl;
  TDMASchedulerP.AnnounceSend 
    -> CXTransportC.SimpleFloodSend[CX_TYPE_SCHEDULE];
  TDMASchedulerP.AnnounceReceive 
    -> CXTransportC.SimpleFloodReceive[CX_TYPE_SCHEDULE];
  TDMASchedulerP.ReplySend 
    -> CXTransportC.SimpleFloodSend[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.ReplyReceive 
    -> CXTransportC.SimpleFloodReceive[CX_TYPE_SCHEDULE_REPLY];
  TDMASchedulerP.TDMAPhySchedule = TDMAPhySchedule;
  TDMASchedulerP.Packet = Packet;
  TDMASchedulerP.CXPacket = CXPacket;
  TDMASchedulerP.CXRoutingTable = CXRoutingTable;
  TDMASchedulerP.CXPacketMetadata = CXPacketMetadata;
  TDMASchedulerP.AMPacket = AMPacket;
  TDMASchedulerP.Rf1aPacket = Rf1aPacket;
  TDMASchedulerP.FrameStarted = FrameStarted;

  TDMARoutingSchedule = TDMASchedulerP;

}
