 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components UtilitiesC;
  components BusC;
  components ToastTLVC;

  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  components SerialActiveMessageC;

  MetadataP.Boot -> MainC;

  MetadataP.Packet -> SerialActiveMessageC;
  MetadataP.SerialSplitControl -> SerialActiveMessageC;

  components new PoolC(message_t, 16);
  MetadataP.Pool -> PoolC;
  UtilitiesC.Pool -> PoolC;
  BusC.Pool -> PoolC;
  ToastTLVC.Pool -> PoolC;

  ToastTLVC.LastSlave -> BusC.Get;

  components LedsC;
  MetadataP.Leds -> LedsC;

//  MetadataP.TLVUtils -> I2CTLVStorageMasterC;

//Begin Auto-generated external wiring (see genExternalWiring.sh)
//Receive
components new SerialAMReceiverC(AM_READ_IV_CMD_MSG) as ReadIvCmdReceive;
MetadataP.ReadIvCmdReceive -> ReadIvCmdReceive;
components new SerialAMReceiverC(AM_READ_MFR_ID_CMD_MSG) as ReadMfrIdCmdReceive;
MetadataP.ReadMfrIdCmdReceive -> ReadMfrIdCmdReceive;
components new SerialAMReceiverC(AM_READ_BACON_BARCODE_ID_CMD_MSG) as ReadBaconBarcodeIdCmdReceive;
MetadataP.ReadBaconBarcodeIdCmdReceive -> ReadBaconBarcodeIdCmdReceive;
components new SerialAMReceiverC(AM_WRITE_BACON_BARCODE_ID_CMD_MSG) as WriteBaconBarcodeIdCmdReceive;
MetadataP.WriteBaconBarcodeIdCmdReceive -> WriteBaconBarcodeIdCmdReceive;
components new SerialAMReceiverC(AM_RESET_BACON_CMD_MSG) as ResetBaconCmdReceive;
MetadataP.ResetBaconCmdReceive -> ResetBaconCmdReceive;
components new SerialAMReceiverC(AM_READ_BACON_TLV_CMD_MSG) as ReadBaconTlvCmdReceive;
MetadataP.ReadBaconTlvCmdReceive -> ReadBaconTlvCmdReceive;
components new SerialAMReceiverC(AM_WRITE_BACON_TLV_CMD_MSG) as WriteBaconTlvCmdReceive;
MetadataP.WriteBaconTlvCmdReceive -> WriteBaconTlvCmdReceive;
components new SerialAMReceiverC(AM_DELETE_BACON_TLV_ENTRY_CMD_MSG) as DeleteBaconTlvEntryCmdReceive;
MetadataP.DeleteBaconTlvEntryCmdReceive -> DeleteBaconTlvEntryCmdReceive;
components new SerialAMReceiverC(AM_ADD_BACON_TLV_ENTRY_CMD_MSG) as AddBaconTlvEntryCmdReceive;
MetadataP.AddBaconTlvEntryCmdReceive -> AddBaconTlvEntryCmdReceive;
//Send
components new SerialAMSenderC(AM_READ_IV_RESPONSE_MSG) as ReadIvResponseSend;
MetadataP.ReadIvResponseSend -> ReadIvResponseSend;
components new SerialAMSenderC(AM_READ_MFR_ID_RESPONSE_MSG) as ReadMfrIdResponseSend;
MetadataP.ReadMfrIdResponseSend -> ReadMfrIdResponseSend;
components new SerialAMSenderC(AM_READ_BACON_BARCODE_ID_RESPONSE_MSG) as ReadBaconBarcodeIdResponseSend;
MetadataP.ReadBaconBarcodeIdResponseSend -> ReadBaconBarcodeIdResponseSend;
components new SerialAMSenderC(AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG) as WriteBaconBarcodeIdResponseSend;
MetadataP.WriteBaconBarcodeIdResponseSend -> WriteBaconBarcodeIdResponseSend;
components new SerialAMSenderC(AM_RESET_BACON_RESPONSE_MSG) as ResetBaconResponseSend;
MetadataP.ResetBaconResponseSend -> ResetBaconResponseSend;
components new SerialAMSenderC(AM_READ_BACON_TLV_RESPONSE_MSG) as ReadBaconTlvResponseSend;
MetadataP.ReadBaconTlvResponseSend -> ReadBaconTlvResponseSend;
components new SerialAMSenderC(AM_WRITE_BACON_TLV_RESPONSE_MSG) as WriteBaconTlvResponseSend;
MetadataP.WriteBaconTlvResponseSend -> WriteBaconTlvResponseSend;
components new SerialAMSenderC(AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG) as DeleteBaconTlvEntryResponseSend;
MetadataP.DeleteBaconTlvEntryResponseSend -> DeleteBaconTlvEntryResponseSend;
components new SerialAMSenderC(AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG) as AddBaconTlvEntryResponseSend;
MetadataP.AddBaconTlvEntryResponseSend -> AddBaconTlvEntryResponseSend;
//End Auto-generated wiring

}
