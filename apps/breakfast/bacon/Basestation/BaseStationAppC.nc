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
  
  components RouterMultiSenderC, GlobalMultiSenderC;
  BaseStationP.GlobalSend -> GlobalMultiSenderC;
  BaseStationP.RouterSend -> RouterMultiSenderC;
  BaseStationP.RadioReceive -> RadioAM.Receive;
  BaseStationP.RadioSnoop -> RadioAM.Snoop;
  BaseStationP.RadioPacket -> RadioAM;
  BaseStationP.RadioAMPacket -> RadioAM;
  
  BaseStationP.Leds -> LedsC;

  components new QueueC(queue_entry_t, 4) as RadioRXQueue;
  components new QueueC(queue_entry_t, 4) as SerialRXQueue;
  components new QueueC(queue_entry_t, 4) as RadioTXQueue;
  components new QueueC(queue_entry_t, 4) as SerialTXQueue;

  BaseStationP.Pool -> RadioAM.Pool;

  BaseStationP.RadioRXQueue -> RadioRXQueue;
  BaseStationP.SerialRXQueue -> SerialRXQueue;
  BaseStationP.RadioTXQueue -> RadioTXQueue;
  BaseStationP.SerialTXQueue -> SerialTXQueue;

  components CXBaseStationC;
  BaseStationP.CXDownload -> CXBaseStationC.CXDownload;
  BaseStationP.StatusReceive -> CXBaseStationC.StatusReceive;

  components new SerialAMReceiverC(AM_CX_DOWNLOAD) 
    as CXDownloadReceive;
  BaseStationP.CXDownloadReceive -> CXDownloadReceive;

  components new SerialAMSenderC(AM_CTRL_ACK) as CtrlAckSend;
  BaseStationP.CtrlAckSend -> CtrlAckSend;

  components new SerialAMSenderC(AM_CX_DOWNLOAD_FINISHED) 
    as CXDownloadFinishedSend;
  BaseStationP.CXDownloadFinishedSend -> CXDownloadFinishedSend;

  components new SerialAMSenderC(AM_STATUS_TIME_REF) 
    as StatusTimeRefSend;
  BaseStationP.StatusTimeRefSend -> StatusTimeRefSend;

  components new DummyLogWriteC();
  components SettingsStorageC;
  SettingsStorageC.LogWrite -> DummyLogWriteC;

  components BareSettingsStorageConfiguratorC;
  BareSettingsStorageConfiguratorC.Pool -> RadioAM.Pool;
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

}
