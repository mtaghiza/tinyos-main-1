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

 #include "leaf.h"
 #include "StorageVolumes.h"
 #include "message.h"
 #include "CXDebug.h"
configuration LeafAppC{
} implementation {
  #if ENABLE_PRINTF == 1
  components SerialPrintfC;
  components SerialStartC;
  #endif

  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
//  components StackGuardMilliUartC;
  #endif

  components MainC;
  components LeafP;
  components CXLeafC;
  components ActiveMessageC;

  #ifndef PHOENIX_LOGGING
  #define PHOENIX_LOGGING 1
  #endif

  #if PHOENIX_LOGGING == 1
  //yeesh this is ugly
  components PhoenixNeighborhoodP;
  components new LogStorageC(VOLUME_RECORD, TRUE) as PhoenixLS;
  PhoenixNeighborhoodP.LogWrite -> PhoenixLS;
  #else
  #warning Phoenix disabled!
  #endif


  #ifndef ENABLE_AUTOPUSH
  #define ENABLE_AUTOPUSH 1
  #endif

  #if ENABLE_AUTOPUSH == 1
  components new RecordPushRequestC(VOLUME_RECORD, TRUE);

  components new AMSenderC(AM_LOG_RECORD_DATA_MSG);
  components new AMReceiverC(AM_CX_RECORD_REQUEST_MSG);
  components CXLinkPacketC;
  RecordPushRequestC.Pool -> ActiveMessageC;
  RecordPushRequestC.AMSend -> AMSenderC;
  RecordPushRequestC.Packet -> AMSenderC;
  RecordPushRequestC.CXLinkPacket -> CXLinkPacketC;
  RecordPushRequestC.Receive -> AMReceiverC;
  RecordPushRequestC.Get -> CXLeafC.Get[NS_SUBNETWORK];

  components SlotSchedulerC;
  SlotSchedulerC.PushCookie -> RecordPushRequestC.PushCookie;
  SlotSchedulerC.WriteCookie -> RecordPushRequestC.WriteCookie;
  SlotSchedulerC.MissingLength -> RecordPushRequestC.MissingLength;

  #else
  #warning Autopush disabled!
  #endif

  #ifndef ENABLE_SETTINGS_CONFIG
  #define ENABLE_SETTINGS_CONFIG 1
  #endif

  #if ENABLE_SETTINGS_CONFIG == 1
  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> ActiveMessageC;
  #else
  #warning SettingsStorageConfigurator disabled!
  #endif
  
  components SettingsStorageC;

  #ifndef ENABLE_SETTINGS_LOGGING
  #define ENABLE_SETTINGS_LOGGING 1
  #endif

  #if ENABLE_SETTINGS_LOGGING == 1
  components new LogStorageC(VOLUME_RECORD, TRUE) as SettingsLS;
  SettingsStorageC.LogWrite -> SettingsLS;
  #else
  #warning Disabled settings logging!
  components new DummyLogWriteC();
  SettingsStorageC.LogWrite -> DummyLogWriteC;
  #endif

//  components PingC;
//  PingC.Pool -> PoolC;

  
  #ifndef ENABLE_TOAST_SAMPLER
  #define ENABLE_TOAST_SAMPLER 1
  #endif

  #if ENABLE_TOAST_SAMPLER == 1
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  #else
  #warning Disabled Toast sampler!
  #endif

  #ifndef ENABLE_BACON_SAMPLER
  #define ENABLE_BACON_SAMPLER 1
  #endif

  #if ENABLE_BACON_SAMPLER == 1
  components new BaconSamplerC(VOLUME_RECORD, TRUE);
  #else
  #warning Disable Bacon sampler!
  #endif
  
  #ifndef REBOOT_INTERVAL
  #define REBOOT_INTERVAL 0
  #endif
  #if REBOOT_INTERVAL != 0
  #warning Automatic reboot enabled.
  components RebooterC;
  #endif

  #ifndef ENABLE_UART_REBOOT
  #define ENABLE_UART_REBOOT 0
  #endif
  #if ENABLE_UART_REBOOT == 1
  #warning UART reboot enabled.
  components UartRebooterC;
  #endif

  #ifndef ENABLE_AUTOSENDER
  #define ENABLE_AUTOSENDER 0
  #endif
  #if ENABLE_AUTOSENDER == 1
  #warning Enabled auto-sender: TEST ONLY
  components AutoSenderC;
  #endif

  #ifndef ENABLE_TESTBED
  #define ENABLE_TESTBED 0
  #endif
  #if ENABLE_TESTBED == 1
  #warning Enable Testbed Router
  components TestbedLeafC;
  #endif

  LeafP.SplitControl -> ActiveMessageC;
  LeafP.Boot -> MainC;

}
