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

 #include "basestation.h"
 #include "CXBasestationDebug.h"
configuration BaseStationAppC {
}
implementation {
  #ifndef ENABLE_PRINTF
  #define ENABLE_PRINTF 0
  #endif
  #if ENABLE_PRINTF == 1
  components SerialStartC;
  components PrintfC;
  #endif
  components MainC; 
  components BaseStationP;
  components LedsC, NoLedsC;
  components ActiveMessageC as RadioAM; 
  components SerialActiveMessageC as SerialAM;

  components StackGuardMilliC;

  
  BaseStationP.Boot -> MainC.Boot;

  BaseStationP.RadioControl -> RadioAM.SplitControl;
  BaseStationP.SerialControl -> SerialAM.SplitControl;

  components SerialMultiSenderC;
  BaseStationP.SerialSend -> SerialMultiSenderC.AMSend;
  BaseStationP.SerialSnoop -> SerialAM.Snoop;
  BaseStationP.SerialPacket -> SerialAM.Packet;
  BaseStationP.SerialAMPacket -> SerialAM.AMPacket;
  
  components RouterMultiSenderC, GlobalMultiSenderC, SubNetworkMultiSenderC;
  BaseStationP.GlobalSend -> GlobalMultiSenderC;
  BaseStationP.RouterSend -> RouterMultiSenderC;
  BaseStationP.SubNetworkSend -> SubNetworkMultiSenderC;
  BaseStationP.RadioReceive -> RadioAM.Receive;
  BaseStationP.RadioSnoop -> RadioAM.Snoop;
  BaseStationP.RadioPacket -> RadioAM;
  BaseStationP.RadioAMPacket -> RadioAM;
  
  BaseStationP.Leds -> LedsC;

  components new QueueC(queue_entry_t, BS_QUEUE_SIZE) as RadioRXQueue;
  components new QueueC(queue_entry_t, BS_QUEUE_SIZE) as SerialRXQueue;
  components new QueueC(queue_entry_t, BS_QUEUE_SIZE) as RadioTXQueue;
  components new QueueC(queue_entry_t, BS_QUEUE_SIZE) as SerialTXQueue;

  components new PoolC(message_t, BS_OUTGOING_POOL_SIZE) as OutgoingPool;

  components new PoolC(message_t, BS_CONTROL_POOL_SIZE) as ControlPool;
  BaseStationP.ControlPool -> ControlPool;
  BaseStationP.OutgoingPool -> OutgoingPool;
  BaseStationP.IncomingPool -> RadioAM;

  BaseStationP.RadioRXQueue -> RadioRXQueue;
  BaseStationP.SerialRXQueue -> SerialRXQueue;
  BaseStationP.RadioTXQueue -> RadioTXQueue;
  BaseStationP.SerialTXQueue -> SerialTXQueue;

  components CXBaseStationC;
  BaseStationP.CXDownload -> CXBaseStationC.CXDownload;
  BaseStationP.StatusReceive -> CXBaseStationC.StatusReceive;

  components new SerialLogStorageC();
  CXBaseStationC.LogWrite -> SerialLogStorageC.LogWrite;
  SerialLogStorageC.Pool -> RadioAM;

  components new SerialAMReceiverC(AM_CX_DOWNLOAD) 
    as CXDownloadReceive;
  BaseStationP.CXDownloadReceive -> CXDownloadReceive;

  components new SerialAMSenderC(AM_FWD_STATUS) as FwdStatusSend;
  BaseStationP.FwdStatusSend -> FwdStatusSend;

  components new SerialAMSenderC(AM_CX_DOWNLOAD_STARTED) as CXDownloadStartedSend;
  BaseStationP.CXDownloadStartedSend -> CXDownloadStartedSend;

  components new SerialAMSenderC(AM_CX_DOWNLOAD_FINISHED) 
    as CXDownloadFinishedSend;
  BaseStationP.CXDownloadFinishedSend -> CXDownloadFinishedSend;

  components new SerialAMSenderC(AM_IDENTIFY_RESPONSE) 
    as IDResponseSend;
  BaseStationP.IDResponseSend -> IDResponseSend;

  components new SerialAMSenderC(AM_CX_EOS_REPORT) as EosSend;
  BaseStationP.EosSend -> EosSend;

  components new DummyLogWriteC();
  components SettingsStorageC;
  SettingsStorageC.LogWrite -> DummyLogWriteC;

  components BareSettingsStorageConfiguratorC;
  BareSettingsStorageConfiguratorC.Pool -> ControlPool;
  components new SerialAMReceiverC(AM_SET_SETTINGS_STORAGE_MSG) 
    as SetReceive;
  components new SerialAMReceiverC(AM_CLEAR_SETTINGS_STORAGE_MSG) 
    as ClearReceive;
  components new SerialAMReceiverC(AM_GET_SETTINGS_STORAGE_CMD_MSG) as GetReceive;
  components new SerialAMSenderC(AM_GET_SETTINGS_STORAGE_RESPONSE_MSG) as GetSend;
  BareSettingsStorageConfiguratorC.SetReceive -> SetReceive;
  BareSettingsStorageConfiguratorC.GetReceive -> GetReceive;
  BareSettingsStorageConfiguratorC.GetSend -> GetSend;
  BareSettingsStorageConfiguratorC.AMPacket -> GetSend.AMPacket;
  BareSettingsStorageConfiguratorC.ClearReceive -> ClearReceive;

  components CXLinkPacketC;
  BaseStationP.CXLinkPacket -> CXLinkPacketC;

  components new TimerMilliC();
  BaseStationP.FlushTimer -> TimerMilliC;

  components CXAMAddressC;
  BaseStationP.ActiveMessageAddress -> CXAMAddressC;

}
