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


 #include "CXLink.h"
configuration CXLinkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;
  
  provides interface CXLinkPacket;
  provides interface Packet;
  provides interface Rf1aPacket;
  //for debug only
  provides interface Rf1aStatus;
  provides interface RadioStateLog;
} implementation {
  components CXLinkP;

  components GDO1CaptureC;
  components new AlarmMicro32C() as FastAlarm;
  components new Timer32khzC() as FrameTimer;
  components Msp430XV2ClockC;
  CXLinkP.FastAlarm -> FastAlarm;
  CXLinkP.FrameTimer -> FrameTimer;
  CXLinkP.SynchCapture -> GDO1CaptureC;
  CXLinkP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  #if CX_RADIOSTATS == 1
  #warning "Serial radio logging enabled"
  components new Rf1aPhysicalLogC() as Rf1aPhysicalC;
  RadioStateLog = Rf1aPhysicalC;
  #else
  components new Rf1aPhysicalC() as Rf1aPhysicalC;
  components DummyRadioStateLogC;
  RadioStateLog = DummyRadioStateLogC;
  #endif

  CXLinkP.Rf1aPhysical -> Rf1aPhysicalC;
  CXLinkP.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  CXLinkP.DelayedSend -> Rf1aPhysicalC;
  CXLinkP.Resource -> Rf1aPhysicalC;
  Rf1aPhysicalC.Rf1aTransmitFragment -> CXLinkP;

  components SRFS7_915_GFSK_125K_SENS_HC as RadioConfigC;
  Rf1aPhysicalC.Rf1aConfigure -> RadioConfigC;
  //TODO: FUTURE wire up a channel cache if desired

  components new PoolC(cx_request_t, REQUEST_QUEUE_LEN);
  components new PriorityQueueC(cx_request_t*, REQUEST_QUEUE_LEN);
  CXLinkP.Pool -> PoolC;
  CXLinkP.Queue -> PriorityQueueC;
  PriorityQueueC.Compare -> CXLinkP;

  SplitControl = CXLinkP;
  CXRequestQueue = CXLinkP;

  components MainC;
  CXLinkP.Boot -> MainC;

  components CXLinkPacketC;
  CXLinkP.Rf1aPacket -> CXLinkPacketC.Rf1aPacket;
  CXLinkP.Packet -> CXLinkPacketC.Packet;
  Packet = CXLinkPacketC.Packet;
  Rf1aPacket = CXLinkPacketC.Rf1aPacket;
  CXLinkPacket = CXLinkPacketC;
  CXLinkPacketC.Rf1aPhysicalMetadata -> Rf1aPhysicalC;

  components CXPacketMetadataC;
  CXLinkP.CXPacketMetadata -> CXPacketMetadataC;

  //for debug only
  Rf1aStatus = Rf1aPhysicalC;

  components StateDumpC;
  CXLinkP.StateDump->StateDumpC;
}
