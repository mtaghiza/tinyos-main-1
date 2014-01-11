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

configuration ToastTLVC{
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
} implementation {
  components ToastTLVP;
  ToastTLVP.LastSlave = LastSlave;
  components MDActiveMessageC as ActiveMessageC;
  ToastTLVP.Pool = Pool;
  ToastTLVP.Packet -> ActiveMessageC;
  ToastTLVP.AMPacket -> ActiveMessageC;

  components I2CTLVStorageMasterC;
  ToastTLVP.I2CTLVStorageMaster -> I2CTLVStorageMasterC;
  ToastTLVP.TLVUtils -> I2CTLVStorageMasterC;

  components new MDAMReceiverC(AM_READ_TOAST_TLV_CMD_MSG) 
    as ReadToastTlvCmdReceive;
  ToastTLVP.ReadToastTlvCmdReceive -> ReadToastTlvCmdReceive;

  components new MDAMReceiverC(AM_WRITE_TOAST_TLV_CMD_MSG) 
    as WriteToastTlvCmdReceive;
  ToastTLVP.WriteToastTlvCmdReceive -> WriteToastTlvCmdReceive;

  components new MDAMReceiverC(AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG) 
    as DeleteToastTlvEntryCmdReceive;
  ToastTLVP.DeleteToastTlvEntryCmdReceive -> DeleteToastTlvEntryCmdReceive;

  components new MDAMReceiverC(AM_ADD_TOAST_TLV_ENTRY_CMD_MSG) 
    as AddToastTlvEntryCmdReceive;
  ToastTLVP.AddToastTlvEntryCmdReceive -> AddToastTlvEntryCmdReceive;

  components new MDAMSenderC(AM_READ_TOAST_TLV_RESPONSE_MSG) 
    as ReadToastTlvResponseSend;
  ToastTLVP.ReadToastTlvResponseSend -> ReadToastTlvResponseSend;

  components new MDAMSenderC(AM_WRITE_TOAST_TLV_RESPONSE_MSG) 
    as WriteToastTlvResponseSend;
  ToastTLVP.WriteToastTlvResponseSend -> WriteToastTlvResponseSend;

  components new MDAMSenderC(AM_DELETE_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as DeleteToastTlvEntryResponseSend;
  ToastTLVP.DeleteToastTlvEntryResponseSend -> DeleteToastTlvEntryResponseSend;

  components new MDAMSenderC(AM_ADD_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as AddToastTlvEntryResponseSend;
  ToastTLVP.AddToastTlvEntryResponseSend -> AddToastTlvEntryResponseSend;

  components new MDAMReceiverC(AM_READ_TOAST_TLV_ENTRY_CMD_MSG) 
    as ReadToastTlvEntryCmdReceive;
  ToastTLVP.ReadToastTlvEntryCmdReceive -> ReadToastTlvEntryCmdReceive;

  components new MDAMSenderC(AM_READ_TOAST_TLV_ENTRY_RESPONSE_MSG) 
    as ReadToastTlvEntryResponseSend;
  ToastTLVP.ReadToastTlvEntryResponseSend -> ReadToastTlvEntryResponseSend;

  components new MDAMSenderC(AM_WRITE_TOAST_VERSION_RESPONSE_MSG) 
    as WriteToastVersionResponseSend;
  ToastTLVP.WriteToastVersionResponseSend -> WriteToastVersionResponseSend;

  components new MDAMSenderC(AM_WRITE_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as WriteToastAssignmentsResponseSend;
  ToastTLVP.WriteToastAssignmentsResponseSend -> WriteToastAssignmentsResponseSend;

  components new MDAMSenderC(AM_WRITE_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as WriteToastBarcodeIdResponseSend;
  ToastTLVP.WriteToastBarcodeIdResponseSend -> WriteToastBarcodeIdResponseSend;

  components new MDAMSenderC(AM_READ_TOAST_BARCODE_ID_RESPONSE_MSG) 
    as ReadToastBarcodeIdResponseSend;
  ToastTLVP.ReadToastBarcodeIdResponseSend -> ReadToastBarcodeIdResponseSend;

  components new MDAMSenderC(AM_READ_TOAST_VERSION_RESPONSE_MSG) 
    as ReadToastVersionResponseSend;
  ToastTLVP.ReadToastVersionResponseSend -> ReadToastVersionResponseSend;

  components new MDAMSenderC(AM_READ_TOAST_ASSIGNMENTS_RESPONSE_MSG) 
    as ReadToastAssignmentsResponseSend;
  ToastTLVP.ReadToastAssignmentsResponseSend -> ReadToastAssignmentsResponseSend;

}
