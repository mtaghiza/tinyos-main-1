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

configuration CXWakeupC {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  provides interface Packet;
  provides interface CXMacPacket;
  provides interface CXLink;
  provides interface CXLinkPacket;

  provides interface LppProbeSniffer;

  uses interface Pool<message_t>;
} implementation {
  components CXWakeupP;
  LppControl = CXWakeupP;
  Send = CXWakeupP.Send;
  Receive = CXWakeupP.Receive;
  SplitControl = CXWakeupP.SplitControl;
  CXLink = CXWakeupP.CXLink;

  components CXLinkC;
  CXWakeupP.SubSplitControl -> CXLinkC.SplitControl;
  CXWakeupP.SubSend -> CXLinkC.Send;
  CXWakeupP.SubReceive -> CXLinkC.Receive;
  CXWakeupP.SubCXLink -> CXLinkC.CXLink;
  CXWakeupP.CXLinkPacket -> CXLinkC.CXLinkPacket;
  CXWakeupP.LinkPacket -> CXLinkC.Packet;

  CXLinkC.Pool = Pool;
  CXWakeupP.Pool = Pool;
  CXLinkPacket = CXLinkC;
  
  components CXMacPacketC;
  CXMacPacketC.SubPacket -> CXLinkC.Packet;
  Packet = CXMacPacketC.Packet;
  CXMacPacket = CXMacPacketC.CXMacPacket;
  CXWakeupP.Packet -> CXMacPacketC.Packet;
  CXWakeupP.CXMacPacket -> CXMacPacketC.CXMacPacket;

  components new TimerMilliC() as ProbeTimer;
  components new TimerMilliC() as TimeoutCheck;
  CXWakeupP.ProbeTimer -> ProbeTimer;
  CXWakeupP.TimeoutCheck -> TimeoutCheck;

  components RandomC;
  CXWakeupP.Random -> RandomC;

  components StateDumpC;
  CXWakeupP.StateDump -> StateDumpC;

  LppProbeSniffer = CXWakeupP.LppProbeSniffer;

  components CXProbeScheduleC;
  CXWakeupP.Get -> CXProbeScheduleC;

  components RebootCounterC;
  CXWakeupP.RebootCounter -> RebootCounterC;

}
