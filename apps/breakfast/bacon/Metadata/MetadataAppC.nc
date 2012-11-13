 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  components SerialActiveMessageC;

  MetadataP.Boot -> MainC;
  MetadataP.Timer -> TimerMilliC;

  MetadataP.Packet -> SerialActiveMessageC;
  MetadataP.SerialSplitControl -> SerialActiveMessageC;

  components new PoolC(message_t, 16);
  MetadataP.Pool -> PoolC;

  components new I2CDiscovererC();
  MetadataP.I2CDiscoverer -> I2CDiscovererC;

  components new BusPowerClientC();
  MetadataP.BusControl -> BusPowerClientC;
  components new TimerMilliC() as ResetTimer;
  MetadataP.ResetTimer -> ResetTimer;

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
components new SerialAMReceiverC(AM_READ_TOAST_BARCODE_ID_CMD_MSG) as ReadToastBarcodeIdCmdReceive;
MetadataP.ReadToastBarcodeIdCmdReceive -> ReadToastBarcodeIdCmdReceive;
components new SerialAMReceiverC(AM_WRITE_TOAST_BARCODE_ID_CMD_MSG) as WriteToastBarcodeIdCmdReceive;
MetadataP.WriteToastBarcodeIdCmdReceive -> WriteToastBarcodeIdCmdReceive;
components new SerialAMReceiverC(AM_READ_TOAST_ASSIGNMENTS_CMD_MSG) as ReadToastAssignmentsCmdReceive;
MetadataP.ReadToastAssignmentsCmdReceive -> ReadToastAssignmentsCmdReceive;
components new SerialAMReceiverC(AM_WRITE_TOAST_ASSIGNMENTS_CMD_MSG) as WriteToastAssignmentsCmdReceive;
MetadataP.WriteToastAssignmentsCmdReceive -> WriteToastAssignmentsCmdReceive;
components new SerialAMReceiverC(AM_SCAN_BUS_CMD_MSG) as ScanBusCmdReceive;
MetadataP.ScanBusCmdReceive -> ScanBusCmdReceive;
components new SerialAMReceiverC(AM_PING_CMD_MSG) as PingCmdReceive;
MetadataP.PingCmdReceive -> PingCmdReceive;
components new SerialAMReceiverC(AM_RESET_BACON_CMD_MSG) as ResetBaconCmdReceive;
MetadataP.ResetBaconCmdReceive -> ResetBaconCmdReceive;
components new SerialAMReceiverC(AM_RESET_BUS_CMD_MSG) as ResetBusCmdReceive;
MetadataP.ResetBusCmdReceive -> ResetBusCmdReceive;
components new SerialAMReceiverC(AM_READ_BACON_TLV_CMD_MSG) as ReadBaconTlvCmdReceive;
MetadataP.ReadBaconTlvCmdReceive -> ReadBaconTlvCmdReceive;
components new SerialAMReceiverC(AM_READ_TOAST_TLV_CMD_MSG) as ReadToastTlvCmdReceive;
MetadataP.ReadToastTlvCmdReceive -> ReadToastTlvCmdReceive;
components new SerialAMReceiverC(AM_WRITE_BACON_TLV_CMD_MSG) as WriteBaconTlvCmdReceive;
MetadataP.WriteBaconTlvCmdReceive -> WriteBaconTlvCmdReceive;
components new SerialAMReceiverC(AM_WRITE_TOAST_TLV_CMD_MSG) as WriteToastTlvCmdReceive;
MetadataP.WriteToastTlvCmdReceive -> WriteToastTlvCmdReceive;
components new SerialAMReceiverC(AM_DELETE_BACON_TLV_ENTRY_CMD_MSG) as DeleteBaconTlvEntryCmdReceive;
MetadataP.DeleteBaconTlvEntryCmdReceive -> DeleteBaconTlvEntryCmdReceive;
components new SerialAMReceiverC(AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG) as DeleteToastTlvEntryCmdReceive;
MetadataP.DeleteToastTlvEntryCmdReceive -> DeleteToastTlvEntryCmdReceive;
components new SerialAMReceiverC(AM_ADD_BACON_TLV_ENTRY_CMD_MSG) as AddBaconTlvEntryCmdReceive;
MetadataP.AddBaconTlvEntryCmdReceive -> AddBaconTlvEntryCmdReceive;
components new SerialAMReceiverC(AM_ADD_TOAST_TLV_ENTRY_CMD_MSG) as AddToastTlvEntryCmdReceive;
MetadataP.AddToastTlvEntryCmdReceive -> AddToastTlvEntryCmdReceive;
//Send
components new SerialAMSenderC(AM_READ_IV_RESPONSE_MSG) as ReadIvResponseSend;
MetadataP.ReadIvResponseSend -> ReadIvResponseSend;
components new SerialAMSenderC(AM_READ_MFR_ID_RESPONSE_MSG) as ReadMfrIdResponseSend;
MetadataP.ReadMfrIdResponseSend -> ReadMfrIdResponseSend;
components new SerialAMSenderC(AM_READ_BACON_BARCODE_ID_RESPONSE_MSG) as ReadBaconBarcodeIdResponseSend;
MetadataP.ReadBaconBarcodeIdResponseSend -> ReadBaconBarcodeIdResponseSend;
components new SerialAMSenderC(AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG) as WriteBaconBarcodeIdResponseSend;
MetadataP.WriteBaconBarcodeIdResponseSend -> WriteBaconBarcodeIdResponseSend;
components new SerialAMSenderC(AM_READ_TOAST_BARCODE_ID_RESPONSE_MSG) as ReadToastBarcodeIdResponseSend;
MetadataP.ReadToastBarcodeIdResponseSend -> ReadToastBarcodeIdResponseSend;
components new SerialAMSenderC(AM_WRITE_TOAST_BARCODE_ID_RESPONSE_MSG) as WriteToastBarcodeIdResponseSend;
MetadataP.WriteToastBarcodeIdResponseSend -> WriteToastBarcodeIdResponseSend;
components new SerialAMSenderC(AM_READ_TOAST_ASSIGNMENTS_RESPONSE_MSG) as ReadToastAssignmentsResponseSend;
MetadataP.ReadToastAssignmentsResponseSend -> ReadToastAssignmentsResponseSend;
components new SerialAMSenderC(AM_WRITE_TOAST_ASSIGNMENTS_RESPONSE_MSG) as WriteToastAssignmentsResponseSend;
MetadataP.WriteToastAssignmentsResponseSend -> WriteToastAssignmentsResponseSend;
components new SerialAMSenderC(AM_SCAN_BUS_RESPONSE_MSG) as ScanBusResponseSend;
MetadataP.ScanBusResponseSend -> ScanBusResponseSend;
components new SerialAMSenderC(AM_PING_RESPONSE_MSG) as PingResponseSend;
MetadataP.PingResponseSend -> PingResponseSend;
components new SerialAMSenderC(AM_RESET_BACON_RESPONSE_MSG) as ResetBaconResponseSend;
MetadataP.ResetBaconResponseSend -> ResetBaconResponseSend;
components new SerialAMSenderC(AM_RESET_BUS_RESPONSE_MSG) as ResetBusResponseSend;
MetadataP.ResetBusResponseSend -> ResetBusResponseSend;
components new SerialAMSenderC(AM_READ_BACON_TLV_RESPONSE_MSG) as ReadBaconTlvResponseSend;
MetadataP.ReadBaconTlvResponseSend -> ReadBaconTlvResponseSend;
components new SerialAMSenderC(AM_READ_TOAST_TLV_RESPONSE_MSG) as ReadToastTlvResponseSend;
MetadataP.ReadToastTlvResponseSend -> ReadToastTlvResponseSend;
components new SerialAMSenderC(AM_WRITE_BACON_TLV_RESPONSE_MSG) as WriteBaconTlvResponseSend;
MetadataP.WriteBaconTlvResponseSend -> WriteBaconTlvResponseSend;
components new SerialAMSenderC(AM_WRITE_TOAST_TLV_RESPONSE_MSG) as WriteToastTlvResponseSend;
MetadataP.WriteToastTlvResponseSend -> WriteToastTlvResponseSend;
components new SerialAMSenderC(AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG) as DeleteBaconTlvEntryResponseSend;
MetadataP.DeleteBaconTlvEntryResponseSend -> DeleteBaconTlvEntryResponseSend;
components new SerialAMSenderC(AM_DELETE_TOAST_TLV_ENTRY_RESPONSE_MSG) as DeleteToastTlvEntryResponseSend;
MetadataP.DeleteToastTlvEntryResponseSend -> DeleteToastTlvEntryResponseSend;
components new SerialAMSenderC(AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG) as AddBaconTlvEntryResponseSend;
MetadataP.AddBaconTlvEntryResponseSend -> AddBaconTlvEntryResponseSend;
components new SerialAMSenderC(AM_ADD_TOAST_TLV_ENTRY_RESPONSE_MSG) as AddToastTlvEntryResponseSend;
MetadataP.AddToastTlvEntryResponseSend -> AddToastTlvEntryResponseSend;
//End Auto-generated wiring

}
