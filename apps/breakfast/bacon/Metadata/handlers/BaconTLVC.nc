configuration BaconTLVC{
  uses interface Pool<message_t>;
} implementation {
  components BaconTLVP;
  components SerialActiveMessageC;
  BaconTLVP.Pool = Pool;
  BaconTLVP.Packet -> SerialActiveMessageC;
  BaconTLVP.AMPacket -> SerialActiveMessageC;

  components TLVStorageC;
  BaconTLVP.TLVStorage-> TLVStorageC;
  BaconTLVP.TLVUtils -> TLVStorageC;

  components new SerialAMReceiverC(AM_READ_BACON_TLV_CMD_MSG) 
    as ReadBaconTlvCmdReceive;
  BaconTLVP.ReadBaconTlvCmdReceive -> ReadBaconTlvCmdReceive;

  components new SerialAMReceiverC(AM_WRITE_BACON_TLV_CMD_MSG) 
    as WriteBaconTlvCmdReceive;
  BaconTLVP.WriteBaconTlvCmdReceive -> WriteBaconTlvCmdReceive;

  components new SerialAMReceiverC(AM_DELETE_BACON_TLV_ENTRY_CMD_MSG) 
    as DeleteBaconTlvEntryCmdReceive;
  BaconTLVP.DeleteBaconTlvEntryCmdReceive -> DeleteBaconTlvEntryCmdReceive;

  components new SerialAMReceiverC(AM_ADD_BACON_TLV_ENTRY_CMD_MSG) 
    as AddBaconTlvEntryCmdReceive;
  BaconTLVP.AddBaconTlvEntryCmdReceive -> AddBaconTlvEntryCmdReceive;

  components new SerialAMSenderC(AM_READ_BACON_TLV_RESPONSE_MSG) 
    as ReadBaconTlvResponseSend;
  BaconTLVP.ReadBaconTlvResponseSend -> ReadBaconTlvResponseSend;

  components new SerialAMSenderC(AM_WRITE_BACON_TLV_RESPONSE_MSG) 
    as WriteBaconTlvResponseSend;
  BaconTLVP.WriteBaconTlvResponseSend -> WriteBaconTlvResponseSend;

  components new SerialAMSenderC(AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteBaconTlvEntryResponseSend;
  BaconTLVP.DeleteBaconTlvEntryResponseSend -> DeleteBaconTlvEntryResponseSend;

  components new SerialAMSenderC(AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as AddBaconTlvEntryResponseSend;
  BaconTLVP.AddBaconTlvEntryResponseSend -> AddBaconTlvEntryResponseSend;

  components new SerialAMReceiverC(AM_READ_BACON_TLV_ENTRY_CMD_MSG) 
    as ReadBaconTlvEntryCmdReceive;
  BaconTLVP.ReadBaconTlvEntryCmdReceive -> ReadBaconTlvEntryCmdReceive;

  components new SerialAMSenderC(AM_READ_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as ReadBaconTlvEntryResponseSend;
  BaconTLVP.ReadBaconTlvEntryResponseSend -> ReadBaconTlvEntryResponseSend;

  components new SerialAMSenderC(AM_WRITE_BACON_VERSION_RESPONSE_MSG) 
    as WriteBaconVersionResponseSend;
  BaconTLVP.WriteBaconVersionResponseSend -> WriteBaconVersionResponseSend;

  components new SerialAMSenderC(AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG) 
    as WriteBaconBarcodeIdResponseSend;
  BaconTLVP.WriteBaconBarcodeIdResponseSend -> WriteBaconBarcodeIdResponseSend;

  components new SerialAMSenderC(AM_READ_BACON_BARCODE_ID_RESPONSE_MSG) 
    as ReadBaconBarcodeIdResponseSend;
  BaconTLVP.ReadBaconBarcodeIdResponseSend -> ReadBaconBarcodeIdResponseSend;

  components new SerialAMSenderC(AM_READ_BACON_VERSION_RESPONSE_MSG) 
    as ReadBaconVersionResponseSend;
  BaconTLVP.ReadBaconVersionResponseSend -> ReadBaconVersionResponseSend;

}
