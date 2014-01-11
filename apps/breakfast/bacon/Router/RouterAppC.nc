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
 #include "message.h"
 #include "CXDebug.h"
 #include "router.h"
configuration RouterAppC{
} implementation {
  #if ENABLE_PRINTF == 1
  #if RAW_SERIAL_PRINTF == 1
  components SerialPrintfC;
  #else
  components SerialStartC;
  components PrintfC;
  #endif
  #endif

  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
  #endif

  components MainC;
  components RouterP;
  components ActiveMessageC;

  
  #ifndef ENABLE_AUTOPUSH
  #define ENABLE_AUTOPUSH 1
  #endif

  #if ENABLE_AUTOPUSH == 1
  components new RecordPushRequestC(VOLUME_RECORD, TRUE);
  components new RouterAMSenderC(AM_LOG_RECORD_DATA_MSG);
  components new AMReceiverC(AM_CX_RECORD_REQUEST_MSG) as RequestReceive;
  components CXLinkPacketC;

  RecordPushRequestC.Pool -> ActiveMessageC;
  RecordPushRequestC.AMSend -> RouterAMSenderC;
  RecordPushRequestC.Packet -> RouterAMSenderC;
  RecordPushRequestC.CXLinkPacket -> CXLinkPacketC;
  RecordPushRequestC.Receive -> RequestReceive;

  components SlotSchedulerC;
  SlotSchedulerC.PushCookie -> RecordPushRequestC.PushCookie;
  SlotSchedulerC.WriteCookie -> RecordPushRequestC.WriteCookie;
  #else
  #warning "Disable autopush"
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
  
  #if ENABLE_AUTOPUSH == 1
  RecordPushRequestC.Get -> CXRouterC.Get[NS_ROUTER];
  #endif

  RouterP.SplitControl -> ActiveMessageC;
  RouterP.Boot -> MainC;

  components new AMReceiverC(AM_LOG_RECORD_DATA_MSG);
  RouterP.ReceiveData -> AMReceiverC;
  RouterP.AMPacket -> AMReceiverC;

  components new LogStorageC(VOLUME_RECORD, TRUE);
  RouterP.LogWrite -> LogStorageC;
  RouterP.Pool -> ActiveMessageC;

  components CXRouterC;
  components new TimerMilliC();
  RouterP.CXDownload -> CXRouterC.CXDownload[NS_SUBNETWORK];
  RouterP.SettingsStorage -> SettingsStorageC;
  RouterP.Timer -> TimerMilliC;

  components new LogStorageC(VOLUME_RECORD, TRUE) 
    as NetworkMembershipLS;
  CXRouterC.LogWrite -> NetworkMembershipLS;

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
  components TestbedRouterC;
  #endif
  
  components LedsC, NoLedsC;

//  components new AMReceiverC(AM_CX_DOWNLOAD) as CXDownloadReceive;
//  RouterP.CXDownloadReceive -> CXDownloadReceive; 
  RouterP.DownloadNotify -> SlotSchedulerC.DownloadNotify[NS_ROUTER];
  RouterP.Leds -> LedsC;
}
