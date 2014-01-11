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

configuration LeafAppC{
} implementation {
  components LeafP as TestP;

  components MainC;
  TestP.Boot -> MainC;


  components RandomC;
  MainC.SoftwareInit -> RandomC;
  TestP.Random -> RandomC;

  components CrcC;
  TestP.Crc -> CrcC;

  /* leds */
  components LedsC;
  TestP.Leds -> LedsC;

  components new TimerMilliC() as LedsTimer;
  TestP.LedsTimer -> LedsTimer;

  /* watchdog */
  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  /***************************************************************************/
  /* sampling related                                                        */
  /***************************************************************************/

  /* bacon sensors */
  components BatteryVoltageC;
  TestP.BatteryControl -> BatteryVoltageC;
  TestP.BatteryVoltage -> BatteryVoltageC;

  components Apds9007C;
  TestP.LightControl -> Apds9007C;
  TestP.Apds9007 -> Apds9007C;
  
  components Mcp9700C;
  TestP.TempControl -> Mcp9700C;
  TestP.Mcp9700 -> Mcp9700C;
  
  /* toast sensors */
  components new I2CDiscovererC();
  TestP.I2CDiscoverer -> I2CDiscovererC;

  components I2CADCReaderMasterC;
  TestP.I2CADCReaderMaster -> I2CADCReaderMasterC;
  
  /* timers */
  components new TimerMilliC() as BaconSampleTimer;
  TestP.BaconSampleTimer -> BaconSampleTimer;

  components new TimerMilliC() as ToastSampleTimer;
  TestP.ToastSampleTimer -> ToastSampleTimer;

  components new TimerMilliC() as StatusSampleTimer;
  TestP.StatusSampleTimer -> StatusSampleTimer;


  /***************************************************************************/
  /* radio related                                                           */
  /***************************************************************************/

  /* Active Message Send/Receive */
  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;
  TestP.PacketAcknowledgements -> ActiveMessageC;

  components new AMSenderC(PERIODIC_CHANNEL) as PeriodicSend;
  TestP.AMPacket -> PeriodicSend;
  TestP.PeriodicSend -> PeriodicSend;

  components new AMSenderC(CONTROL_CHANNEL) as ControlSend;
  TestP.ControlSend -> ControlSend;

  components new AMReceiverC(CONTROL_CHANNEL) as ControlReceive;
  TestP.ControlReceive -> ControlReceive;

  components Rf1aActiveMessageC;
  TestP.Rf1aPacket -> Rf1aActiveMessageC;
  TestP.PhysicalControl -> Rf1aActiveMessageC.PhysicalControl;

  /* message buffer/queue */
  components new PoolC(message_t, SEND_POOL_SIZE) as SendPool;
  TestP.SendPool -> SendPool;

  components new QueueC(message_t*, SEND_POOL_SIZE) as SendQueue;
  TestP.SendQueue -> SendQueue;

  /* offload timer */
  components new TimerMilliC() as OffloadTimer;
  TestP.OffloadTimer -> OffloadTimer;

  /* transmit delay timer */
  components new TimerMilliC() as DelayTimer;
  TestP.DelayTimer -> DelayTimer;

  /***************************************************************************/
  /* storage related                                                         */
  /***************************************************************************/

  /* flash */
  components new LogStorageC(VOLUME_SENSORLOG, TRUE);
  TestP.LogRead -> LogStorageC;
  TestP.LogWrite -> LogStorageC;

  components new PoolC(sample_t, SAMPLE_POOL_SIZE) as WritePool;
  TestP.WritePool -> WritePool;

  components new QueueC(sample_t*, SAMPLE_POOL_SIZE) as WriteQueue;
  TestP.WriteQueue -> WriteQueue;


  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port10;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;
  TestP.ToastEnable -> HplMsp430GeneralIOC.Port37;

#ifdef DEBUG
  /* UART */
  components SerialPrintfC;

  components PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
#endif
}
