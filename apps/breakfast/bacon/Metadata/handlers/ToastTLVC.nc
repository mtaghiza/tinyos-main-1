configuration ToastTLVC{
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
} implementation {
  components ToastTLVP;
  ToastTLVP.LastSlave = LastSlave;
  components SerialActiveMessageC;
  ToastTLVP.Pool = Pool;
  ToastTLVP.Packet -> SerialActiveMessageC;
  ToastTLVP.AMPacket -> SerialActiveMessageC;

  components I2CTLVStorageMasterC;
  ToastTLVP.I2CTLVStorageMaster -> I2CTLVStorageMasterC;
  ToastTLVP.TLVUtils -> I2CTLVStorageMasterC;

  components new SerialAMReceiverC(AM_READ_TOAST_TLV_CMD_MSG) 
    as ReadToastTlvCmdReceive;
  ToastTLVP.ReadToastTlvCmdReceive -> ReadToastTlvCmdReceive;

  components new SerialAMReceiverC(AM_WRITE_TOAST_TLV_CMD_MSG) 
    as WriteToastTlvCmdReceive;
  ToastTLVP.WriteToastTlvCmdReceive -> WriteToastTlvCmdReceive;

  components new SerialAMReceiverC(AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG) 
    as DeleteToastTlvEntryCmdReceive;
  ToastTLVP.DeleteToastTlvEntryCmdReceive -> DeleteToastTlvEntryCmdReceive;

  components new SerialAMReceiverC(AM_ADD_TOAST_TLV_ENTRY_CMD_MSG) 
    as AddToastTlvEntryCmdReceive;
  ToastTLVP.AddToastTlvEntryCmdReceive -> AddToastTlvEntryCmdReceive;

  components new SerialAMSenderC(AM_READ_TOAST_TLV_RESPONSE_MSG) 
    as ReadToastTlvResponseSend;
  ToastTLVP.ReadToastTlvResponseSend -> ReadToastTlvResponseSend;

  components new SerialAMSenderC(AM_WRITE_TOAST_TLV_RESPONSE_MSG) 
    as WriteToastTlvResponseSend;
  ToastTLVP.WriteToastTlvResponseSend -> WriteToastTlvResponseSend;

  components new SerialAMSenderC(AM_DELETE_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteToastTlvEntryResponseSend;
  ToastTLVP.DeleteToastTlvEntryResponseSend -> DeleteToastTlvEntryResponseSend;

  components new SerialAMSenderC(AM_ADD_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as AddToastTlvEntryResponseSend;
  ToastTLVP.AddToastTlvEntryResponseSend -> AddToastTlvEntryResponseSend;

  components new SerialAMReceiverC(AM_READ_TOAST_TLV_ENTRY_CMD_MSG) 
    as ReadToastTlvEntryCmdReceive;
  ToastTLVP.ReadToastTlvEntryCmdReceive -> ReadToastTlvEntryCmdReceive;

  components new SerialAMSenderC(AM_READ_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as ReadToastTlvEntryResponseSend;
  ToastTLVP.ReadToastTlvEntryResponseSend -> ReadToastTlvEntryResponseSend;

  components new SerialAMSenderC(AM_WRITE_TOAST_VERSION_RESPONSE_MSG) 
    as WriteToastVersionResponseSend;
  ToastTLVP.WriteToastVersionResponseSend -> WriteToastVersionResponseSend;

  components new SerialAMSenderC(AM_WRITE_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as WriteToastAssignmentsResponseSend;
  ToastTLVP.WriteToastAssignmentsResponseSend -> WriteToastAssignmentsResponseSend;

  components new SerialAMSenderC(AM_WRITE_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as WriteToastBarcodeIdResponseSend;
  ToastTLVP.WriteToastBarcodeIdResponseSend -> WriteToastBarcodeIdResponseSend;

  components new SerialAMSenderC(AM_READ_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as ReadToastBarcodeIdResponseSend;
  ToastTLVP.ReadToastBarcodeIdResponseSend -> ReadToastBarcodeIdResponseSend;

  components new SerialAMSenderC(AM_READ_TOAST_VERSION_RESPONSE_MSG) 
    as ReadToastVersionResponseSend;
  ToastTLVP.ReadToastVersionResponseSend -> ReadToastVersionResponseSend;

  components new SerialAMSenderC(AM_READ_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as ReadToastAssignmentsResponseSend;
  ToastTLVP.ReadToastAssignmentsResponseSend -> ReadToastAssignmentsResponseSend;

}
