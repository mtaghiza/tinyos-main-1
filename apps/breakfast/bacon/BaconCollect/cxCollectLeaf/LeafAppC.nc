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
#include "test.h"
#include "CXTransport.h"

//#define DEBUG 1
//#define USE_TOAST_ADC
//#define USE_BACON_ADC

#ifdef DEBUG
#include <stdio.h>
#else
int printf ( const char * format, ... ) {return 0;}
#endif


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
#ifdef USE_BACON_ADC  
  components BatteryVoltageC;
  TestP.BatteryControl -> BatteryVoltageC;
  TestP.BatteryVoltage -> BatteryVoltageC;

  components Apds9007C;
  TestP.LightControl -> Apds9007C;
  TestP.Apds9007 -> Apds9007C;
  
  components Mcp9700C;
  TestP.TempControl -> Mcp9700C;
  TestP.Mcp9700 -> Mcp9700C;

  components new TimerMilliC() as BaconSampleTimer;
  TestP.BaconSampleTimer -> BaconSampleTimer;
#endif

  /* toast sensors */
#ifdef USE_TOAST_ADC  
  components new I2CDiscovererC();
  TestP.I2CDiscoverer -> I2CDiscovererC;

  components I2CADCReaderMasterC;
  TestP.I2CADCReaderMaster -> I2CADCReaderMasterC;

  components new TimerMilliC() as ToastSampleTimer;
  TestP.ToastSampleTimer -> ToastSampleTimer;
#endif

  components new TimerMilliC() as StatusSampleTimer;
  TestP.StatusSampleTimer -> StatusSampleTimer;



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



  /***************************************************************************/
  /* cx related                                                         */
  /***************************************************************************/

  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;
  TestP.Rf1aPacket -> ActiveMessageC;  
  TestP.AMPacket -> ActiveMessageC;

  components new AMReceiverC(CONTROL_CHANNEL);
  TestP.ControlReceive -> AMReceiverC;

  components new CXAMSenderC(PERIODIC_CHANNEL, CX_TP_RELIABLE_BURST) as PeriodicSendC;
  TestP.PeriodicSend -> PeriodicSendC;

  components new CXAMSenderC(CONTROL_CHANNEL, CX_TP_RELIABLE_BURST) as ControlSendC;
  TestP.ControlSend -> ControlSendC;


  /***************************************************************************/
  /* radio related                                                           */
  /***************************************************************************/

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

}
