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

#include "StorageVolumes.h"
#include "baconCollect.h"

configuration GateAppC{
} implementation {
  components GateP as TestP;

  components MainC, LedsC;
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;

  components RandomC;
  MainC.SoftwareInit -> RandomC;
  TestP.Random -> RandomC;

  components CrcC;
  TestP.Crc -> CrcC;

  components new LogStorageC(VOLUME_SENSORLOG, TRUE);
  TestP.LogRead -> LogStorageC;
  TestP.LogWrite -> LogStorageC;
  
  
  /* timers */
  components new TimerMilliC() as StatusTimer;
  TestP.StatusTimer -> StatusTimer;

  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  components new TimerMilliC() as ClockTimer;
  TestP.ClockTimer -> ClockTimer;

  components new TimerMilliC() as LedsTimer;
  TestP.LedsTimer -> LedsTimer;

  /* UART */
  components PlatformSerialC;
  components SerialPrintfC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  /* Radio */
  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;
  TestP.PacketAcknowledgements -> ActiveMessageC;

  components new AMReceiverC(PERIODIC_CHANNEL) as PeriodicReceive;
  TestP.AMPacket -> PeriodicReceive;
  TestP.PeriodicReceive -> PeriodicReceive;

  components new AMSenderC(CONTROL_CHANNEL) as ControlSend;
  TestP.ControlSend -> ControlSend;
  components new AMReceiverC(CONTROL_CHANNEL) as ControlReceive;
  TestP.ControlReceive -> ControlReceive;

  components new AMReceiverC(MASTER_CONTROL_CHANNEL) as MasterControlReceive;
  TestP.MasterControlReceive -> MasterControlReceive;

  components Rf1aActiveMessageC;
  TestP.Rf1aPacket -> Rf1aActiveMessageC;
  TestP.PhysicalControl -> Rf1aActiveMessageC.PhysicalControl;

  components new PoolC(message_t, SEND_POOL_SIZE);
  TestP.Pool -> PoolC;

  components new QueueC(message_t*, SEND_POOL_SIZE);
  TestP.Queue -> QueueC;

  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port11;
  TestP.CD -> HplMsp430GeneralIOC.Port24;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;

}
