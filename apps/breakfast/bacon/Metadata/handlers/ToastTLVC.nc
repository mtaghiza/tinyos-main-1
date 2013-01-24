configuration ToastTLVC{
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
} implementation {
  components ToastTLVP;
  ToastTLVP.LastSlave = LastSlave;
  components ActiveMessageC;
  ToastTLVP.Pool = Pool;
  ToastTLVP.Packet -> ActiveMessageC;
  ToastTLVP.AMPacket -> ActiveMessageC;

  components I2CTLVStorageMasterC;
  ToastTLVP.I2CTLVStorageMaster -> I2CTLVStorageMasterC;
  ToastTLVP.TLVUtils -> I2CTLVStorageMasterC;

  components new AMReceiverC(AM_READ_TOAST_TLV_CMD_MSG) 
    as ReadToastTlvCmdReceive;
  ToastTLVP.ReadToastTlvCmdReceive -> ReadToastTlvCmdReceive;

  components new AMReceiverC(AM_WRITE_TOAST_TLV_CMD_MSG) 
    as WriteToastTlvCmdReceive;
  ToastTLVP.WriteToastTlvCmdReceive -> WriteToastTlvCmdReceive;

  components new AMReceiverC(AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG) 
    as DeleteToastTlvEntryCmdReceive;
  ToastTLVP.DeleteToastTlvEntryCmdReceive -> DeleteToastTlvEntryCmdReceive;

  components new AMReceiverC(AM_ADD_TOAST_TLV_ENTRY_CMD_MSG) 
    as AddToastTlvEntryCmdReceive;
  ToastTLVP.AddToastTlvEntryCmdReceive -> AddToastTlvEntryCmdReceive;

  components new AMSenderC(AM_READ_TOAST_TLV_RESPONSE_MSG) 
    as ReadToastTlvResponseSend;
  ToastTLVP.ReadToastTlvResponseSend -> ReadToastTlvResponseSend;

  components new AMSenderC(AM_WRITE_TOAST_TLV_RESPONSE_MSG) 
    as WriteToastTlvResponseSend;
  ToastTLVP.WriteToastTlvResponseSend -> WriteToastTlvResponseSend;

  components new AMSenderC(AM_DELETE_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteToastTlvEntryResponseSend;
  ToastTLVP.DeleteToastTlvEntryResponseSend -> DeleteToastTlvEntryResponseSend;

  components new AMSenderC(AM_ADD_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as AddToastTlvEntryResponseSend;
  ToastTLVP.AddToastTlvEntryResponseSend -> AddToastTlvEntryResponseSend;

  components new AMReceiverC(AM_READ_TOAST_TLV_ENTRY_CMD_MSG) 
    as ReadToastTlvEntryCmdReceive;
  ToastTLVP.ReadToastTlvEntryCmdReceive -> ReadToastTlvEntryCmdReceive;

  components new AMSenderC(AM_READ_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as ReadToastTlvEntryResponseSend;
  ToastTLVP.ReadToastTlvEntryResponseSend -> ReadToastTlvEntryResponseSend;

  components new AMSenderC(AM_WRITE_TOAST_VERSION_RESPONSE_MSG) 
    as WriteToastVersionResponseSend;
  ToastTLVP.WriteToastVersionResponseSend -> WriteToastVersionResponseSend;

  components new AMSenderC(AM_WRITE_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as WriteToastAssignmentsResponseSend;
  ToastTLVP.WriteToastAssignmentsResponseSend -> WriteToastAssignmentsResponseSend;

  components new AMSenderC(AM_WRITE_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as WriteToastBarcodeIdResponseSend;
  ToastTLVP.WriteToastBarcodeIdResponseSend -> WriteToastBarcodeIdResponseSend;

  components new AMSenderC(AM_READ_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as ReadToastBarcodeIdResponseSend;
  ToastTLVP.ReadToastBarcodeIdResponseSend -> ReadToastBarcodeIdResponseSend;

  components new AMSenderC(AM_READ_TOAST_VERSION_RESPONSE_MSG) 
    as ReadToastVersionResponseSend;
  ToastTLVP.ReadToastVersionResponseSend -> ReadToastVersionResponseSend;

  components new AMSenderC(AM_READ_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as ReadToastAssignmentsResponseSend;
  ToastTLVP.ReadToastAssignmentsResponseSend -> ReadToastAssignmentsResponseSend;

}
