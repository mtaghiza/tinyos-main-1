configuration BaconTLVC{
  uses interface Pool<message_t>;
} implementation {
  components BaconTLVP;
  components ActiveMessageC;
  BaconTLVP.Pool = Pool;
  BaconTLVP.Packet -> ActiveMessageC;
  BaconTLVP.AMPacket -> ActiveMessageC;

  components TLVStorageC;
  BaconTLVP.TLVStorage-> TLVStorageC;
  BaconTLVP.TLVUtils -> TLVStorageC;

  components new AMReceiverC(AM_READ_BACON_TLV_CMD_MSG) 
    as ReadBaconTlvCmdReceive;
  BaconTLVP.ReadBaconTlvCmdReceive -> ReadBaconTlvCmdReceive;

  components new AMReceiverC(AM_WRITE_BACON_TLV_CMD_MSG) 
    as WriteBaconTlvCmdReceive;
  BaconTLVP.WriteBaconTlvCmdReceive -> WriteBaconTlvCmdReceive;

  components new AMReceiverC(AM_DELETE_BACON_TLV_ENTRY_CMD_MSG) 
    as DeleteBaconTlvEntryCmdReceive;
  BaconTLVP.DeleteBaconTlvEntryCmdReceive -> DeleteBaconTlvEntryCmdReceive;

  components new AMReceiverC(AM_ADD_BACON_TLV_ENTRY_CMD_MSG) 
    as AddBaconTlvEntryCmdReceive;
  BaconTLVP.AddBaconTlvEntryCmdReceive -> AddBaconTlvEntryCmdReceive;

  components new AMSenderC(AM_READ_BACON_TLV_RESPONSE_MSG) 
    as ReadBaconTlvResponseSend;
  BaconTLVP.ReadBaconTlvResponseSend -> ReadBaconTlvResponseSend;

  components new AMSenderC(AM_WRITE_BACON_TLV_RESPONSE_MSG) 
    as WriteBaconTlvResponseSend;
  BaconTLVP.WriteBaconTlvResponseSend -> WriteBaconTlvResponseSend;

  components new AMSenderC(AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteBaconTlvEntryResponseSend;
  BaconTLVP.DeleteBaconTlvEntryResponseSend -> DeleteBaconTlvEntryResponseSend;

  components new AMSenderC(AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as AddBaconTlvEntryResponseSend;
  BaconTLVP.AddBaconTlvEntryResponseSend -> AddBaconTlvEntryResponseSend;

  components new AMReceiverC(AM_READ_BACON_TLV_ENTRY_CMD_MSG) 
    as ReadBaconTlvEntryCmdReceive;
  BaconTLVP.ReadBaconTlvEntryCmdReceive -> ReadBaconTlvEntryCmdReceive;

  components new AMSenderC(AM_READ_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as ReadBaconTlvEntryResponseSend;
  BaconTLVP.ReadBaconTlvEntryResponseSend -> ReadBaconTlvEntryResponseSend;

  components new AMSenderC(AM_WRITE_BACON_VERSION_RESPONSE_MSG) 
    as WriteBaconVersionResponseSend;
  BaconTLVP.WriteBaconVersionResponseSend -> WriteBaconVersionResponseSend;

  components new AMSenderC(AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG) 
    as WriteBaconBarcodeIdResponseSend;
  BaconTLVP.WriteBaconBarcodeIdResponseSend -> WriteBaconBarcodeIdResponseSend;

  components new AMSenderC(AM_READ_BACON_BARCODE_ID_RESPONSE_MSG) 
    as ReadBaconBarcodeIdResponseSend;
  BaconTLVP.ReadBaconBarcodeIdResponseSend -> ReadBaconBarcodeIdResponseSend;

  components new AMSenderC(AM_READ_BACON_VERSION_RESPONSE_MSG) 
    as ReadBaconVersionResponseSend;
  BaconTLVP.ReadBaconVersionResponseSend -> ReadBaconVersionResponseSend;

}
