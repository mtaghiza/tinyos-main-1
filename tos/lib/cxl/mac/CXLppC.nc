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

configuration CXLppC {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  provides interface Packet;
  provides interface CXMacPacket;

  uses interface Pool<message_t>;
} implementation {
  components CXLppP;
  LppControl = CXLppP;
  Send = CXLppP.Send;
  Receive = CXLppP.Receive;
  SplitControl = CXLppP.SplitControl;

  components CXLinkC;
  CXLppP.SubSplitControl -> CXLinkC.SplitControl;
  CXLppP.SubSend -> CXLinkC.Send;
  CXLppP.SubReceive -> CXLinkC.Receive;
  CXLppP.CXLink -> CXLinkC.CXLink;
  CXLppP.CXLinkPacket -> CXLinkC.CXLinkPacket;
  CXLppP.LinkPacket -> CXLinkC.Packet;

  CXLinkC.Pool = Pool;
  CXLppP.Pool = Pool;
  
  components CXMacPacketC;
  CXMacPacketC.SubPacket -> CXLinkC.Packet;
  Packet = CXMacPacketC.Packet;
  CXMacPacket = CXMacPacketC.CXMacPacket;
  CXLppP.Packet -> CXMacPacketC.Packet;
  CXLppP.CXMacPacket -> CXMacPacketC.CXMacPacket;

  components new TimerMilliC() as ProbeTimer;
  components new TimerMilliC() as SleepTimer;
  components new TimerMilliC() as KeepAliveTimer;
  components new TimerMilliC() as TimeoutCheck;
  CXLppP.ProbeTimer -> ProbeTimer;
  CXLppP.SleepTimer -> SleepTimer;
  CXLppP.KeepAliveTimer -> KeepAliveTimer;
  CXLppP.TimeoutCheck -> TimeoutCheck;

  components RandomC;
  CXLppP.Random -> RandomC;

  components StateDumpC;
  CXLppP.StateDump -> StateDumpC;

}
