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
