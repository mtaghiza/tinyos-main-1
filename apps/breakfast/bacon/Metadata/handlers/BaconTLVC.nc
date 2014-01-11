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

configuration BaconTLVC{
  uses interface Pool<message_t>;
} implementation {
  components BaconTLVP;
  components MDActiveMessageC as ActiveMessageC;
  BaconTLVP.Pool = Pool;
  BaconTLVP.Packet -> ActiveMessageC;
  BaconTLVP.AMPacket -> ActiveMessageC;

  components TLVStorageC;
  BaconTLVP.TLVStorage-> TLVStorageC;
  BaconTLVP.TLVUtils -> TLVStorageC;

  components new MDAMReceiverC(AM_READ_BACON_TLV_CMD_MSG) 
    as ReadBaconTlvCmdReceive;
  BaconTLVP.ReadBaconTlvCmdReceive -> ReadBaconTlvCmdReceive;

  components new MDAMReceiverC(AM_WRITE_BACON_TLV_CMD_MSG) 
    as WriteBaconTlvCmdReceive;
  BaconTLVP.WriteBaconTlvCmdReceive -> WriteBaconTlvCmdReceive;

  components new MDAMReceiverC(AM_DELETE_BACON_TLV_ENTRY_CMD_MSG) 
    as DeleteBaconTlvEntryCmdReceive;
  BaconTLVP.DeleteBaconTlvEntryCmdReceive -> DeleteBaconTlvEntryCmdReceive;

  components new MDAMReceiverC(AM_ADD_BACON_TLV_ENTRY_CMD_MSG) 
    as AddBaconTlvEntryCmdReceive;
  BaconTLVP.AddBaconTlvEntryCmdReceive -> AddBaconTlvEntryCmdReceive;

  components new MDAMSenderC(AM_READ_BACON_TLV_RESPONSE_MSG) 
    as ReadBaconTlvResponseSend;
  BaconTLVP.ReadBaconTlvResponseSend -> ReadBaconTlvResponseSend;

  components new MDAMSenderC(AM_WRITE_BACON_TLV_RESPONSE_MSG) 
    as WriteBaconTlvResponseSend;
  BaconTLVP.WriteBaconTlvResponseSend -> WriteBaconTlvResponseSend;

  components new MDAMSenderC(AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteBaconTlvEntryResponseSend;
  BaconTLVP.DeleteBaconTlvEntryResponseSend -> DeleteBaconTlvEntryResponseSend;

  components new MDAMSenderC(AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as AddBaconTlvEntryResponseSend;
  BaconTLVP.AddBaconTlvEntryResponseSend -> AddBaconTlvEntryResponseSend;

  components new MDAMReceiverC(AM_READ_BACON_TLV_ENTRY_CMD_MSG) 
    as ReadBaconTlvEntryCmdReceive;
  BaconTLVP.ReadBaconTlvEntryCmdReceive -> ReadBaconTlvEntryCmdReceive;

  components new MDAMSenderC(AM_READ_BACON_TLV_ENTRY_RESPONSE_MSG) 
    as ReadBaconTlvEntryResponseSend;
  BaconTLVP.ReadBaconTlvEntryResponseSend -> ReadBaconTlvEntryResponseSend;

  components new MDAMSenderC(AM_WRITE_BACON_VERSION_RESPONSE_MSG) 
    as WriteBaconVersionResponseSend;
  BaconTLVP.WriteBaconVersionResponseSend -> WriteBaconVersionResponseSend;

  components new MDAMSenderC(AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG) 
    as WriteBaconBarcodeIdResponseSend;
  BaconTLVP.WriteBaconBarcodeIdResponseSend -> WriteBaconBarcodeIdResponseSend;

  components new MDAMSenderC(AM_READ_BACON_BARCODE_ID_RESPONSE_MSG) 
    as ReadBaconBarcodeIdResponseSend;
  BaconTLVP.ReadBaconBarcodeIdResponseSend -> ReadBaconBarcodeIdResponseSend;

  components new MDAMSenderC(AM_READ_BACON_VERSION_RESPONSE_MSG) 
    as ReadBaconVersionResponseSend;
  BaconTLVP.ReadBaconVersionResponseSend -> ReadBaconVersionResponseSend;

}
