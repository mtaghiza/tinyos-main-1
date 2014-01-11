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

 #include "I2CCom.h"
 #include "I2CTLVStorage.h"
 #include "metadata.h"
module ToastTLVP{
  uses interface Packet;
  uses interface AMPacket;
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
  uses interface I2CTLVStorageMaster;
  uses interface TLVUtils;

  uses interface Receive as ReadToastBarcodeIdCmdReceive;
  uses interface Receive as WriteToastBarcodeIdCmdReceive;
//  uses interface Receive as ReadToastAssignmentsCmdReceive;
  uses interface Receive as WriteToastAssignmentsCmdReceive;
  uses interface Receive as ReadToastTlvCmdReceive;
  uses interface Receive as WriteToastTlvCmdReceive;
  uses interface Receive as DeleteToastTlvEntryCmdReceive;
  uses interface Receive as AddToastTlvEntryCmdReceive;
  uses interface Receive as ReadToastTlvEntryCmdReceive;
  uses interface AMSend as ReadToastBarcodeIdResponseSend;
  uses interface AMSend as WriteToastBarcodeIdResponseSend;
//  uses interface AMSend as ReadToastAssignmentsResponseSend;
  uses interface AMSend as WriteToastAssignmentsResponseSend;
  uses interface AMSend as ReadToastTlvResponseSend;
  uses interface AMSend as WriteToastTlvResponseSend;
  uses interface AMSend as DeleteToastTlvEntryResponseSend;
  uses interface AMSend as AddToastTlvEntryResponseSend;
  uses interface AMSend as ReadToastTlvEntryResponseSend;

} implementation {
  message_t* responseMsg = NULL;
  message_t* cmdMsg = NULL;

  error_t loadTLVError;

  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;

  void* tlvs;
  am_id_t currentCommandType;

  task void handleLoaded();
  task void respondReadToastTlv();
  task void respondReadToastTlvEntry();
  task void respondAddToastTlvEntry();
  task void respondDeleteToastTlvEntry();
  task void respondWriteToastBarcodeId();
  task void respondReadToastBarcodeId();
  task void respondWriteToastAssignments();

  task void loadToastTLVStorage(){
    loadTLVError = call I2CTLVStorageMaster.loadTLVStorage((call LastSlave.get()),
      i2c_msg);

    if (loadTLVError  != SUCCESS){
      post handleLoaded();
    }
  }

  event void I2CTLVStorageMaster.loaded(error_t error, i2c_message_t* msg_){
    tlvs = call I2CTLVStorageMaster.getPayload(msg_);
    loadTLVError = error;
    post handleLoaded();
  }

  task void handleLoaded(){
    if (loadTLVError == SUCCESS){
      switch (currentCommandType){
        case AM_READ_TOAST_TLV_CMD_MSG:
          post respondReadToastTlv();
          break;
        case AM_READ_TOAST_TLV_ENTRY_CMD_MSG:
          post respondReadToastTlvEntry();
          break;
        case AM_ADD_TOAST_TLV_ENTRY_CMD_MSG:
          post respondAddToastTlvEntry();
          break;
        case AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG:
          post respondDeleteToastTlvEntry();
          break;
        case AM_WRITE_TOAST_BARCODE_ID_CMD_MSG:
          post respondWriteToastBarcodeId();
          break;
        case AM_READ_TOAST_BARCODE_ID_CMD_MSG:
          post respondReadToastBarcodeId();
          break;
        case AM_WRITE_TOAST_ASSIGNMENTS_CMD_MSG:
          post respondWriteToastAssignments();
          break;
        default:
          printf("Unknown command %x\n", currentCommandType);
      }
    } else {
      read_toast_tlv_response_msg_t* responsePl = (read_toast_tlv_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_tlv_response_msg_t)));
      responsePl->error = loadTLVError;
      switch (currentCommandType){
        case AM_READ_TOAST_TLV_CMD_MSG:
          call ReadToastTlvResponseSend.send(0, responseMsg, 
            sizeof(read_toast_tlv_response_msg_t));
          break;
        case AM_READ_TOAST_TLV_ENTRY_CMD_MSG:
          call ReadToastTlvEntryResponseSend.send(0, responseMsg, 
            sizeof(read_toast_tlv_entry_response_msg_t));
          break;
        default:
          printf("Unrecognized current command: %x\n",
            currentCommandType);
          break;
      }
      currentCommandType = 0;
    }
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){
    add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(add_toast_tlv_entry_response_msg_t)));
    responsePl->error = error;

    switch(currentCommandType){
      case AM_ADD_TOAST_TLV_ENTRY_CMD_MSG:
        call AddToastTlvEntryResponseSend.send(0, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
        break;
      case AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG:
        call DeleteToastTlvEntryResponseSend.send(0, responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t));
        break;
      case AM_WRITE_TOAST_TLV_CMD_MSG:
        call WriteToastTlvResponseSend.send(0, responseMsg, sizeof(write_toast_tlv_response_msg_t));
        break;
      case AM_WRITE_TOAST_BARCODE_ID_CMD_MSG:
        call WriteToastBarcodeIdResponseSend.send(0, responseMsg, sizeof(write_toast_barcode_id_response_msg_t));
        break;
      case AM_WRITE_TOAST_ASSIGNMENTS_CMD_MSG:
        call WriteToastAssignmentsResponseSend.send(0, responseMsg,
          sizeof(write_toast_assignments_response_msg_t));
        break;
      default:
        printf("Unrecognized command: %x\n", currentCommandType);
    }
  }

  event message_t* ReadToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: ReadToastTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: ReadToastTlv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadToastTlv(){
    error_t err;
    read_toast_tlv_response_msg_t* responsePl = (read_toast_tlv_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_tlv_response_msg_t)));
    memcpy(&(responsePl->tlvs), tlvs, 64);
    responsePl->error = SUCCESS;
    err = call ReadToastTlvResponseSend.send(0, responseMsg, sizeof(read_toast_tlv_response_msg_t));
  }

  event void ReadToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  task void respondWriteToastTlv();

  event message_t* WriteToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: WriteToastTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post respondWriteToastTlv();
          return ret;
        }
      }else{
        printf("RX: WriteToastTlv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastTlv(){
    write_toast_tlv_cmd_msg_t* commandPl = (write_toast_tlv_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(write_toast_tlv_cmd_msg_t)));
    error_t error = SUCCESS;
    tlv_entry_t* e;
    tlvs = call I2CTLVStorageMaster.getPayload(i2c_msg);
    memcpy(tlvs, commandPl->tlvs, 64);
    //verify that there is a TAG_VERSION in here somewhere: otherwise,
    //toast will reject it.
    if (0 == call TLVUtils.findEntry(TAG_VERSION, 0, &e, tlvs)){
      error = EINVAL;
    }else{
      error = call I2CTLVStorageMaster.persistTLVStorage(call LastSlave.get(),
        i2c_msg);
    }
    if (error != SUCCESS){
      write_toast_tlv_response_msg_t* responsePl = (write_toast_tlv_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(write_toast_tlv_response_msg_t)));
      responsePl->error = error;
      call WriteToastTlvResponseSend.send(0, responseMsg, sizeof(write_toast_tlv_response_msg_t));
    }
  }

  event void WriteToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  event message_t* DeleteToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: DeleteToastTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: DeleteToastTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondDeleteToastTlvEntry(){
    delete_toast_tlv_entry_cmd_msg_t* commandPl = (delete_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(delete_toast_tlv_entry_cmd_msg_t)));
    tlv_entry_t* e;
    uint8_t offset = call TLVUtils.findEntry(commandPl->tag, 0, &e,
      tlvs);
    error_t error = SUCCESS;
    if (offset == 0){
      error = EINVAL;
    }else{
      error = call TLVUtils.deleteEntry(offset, tlvs);
      if (error == SUCCESS){
        error = call I2CTLVStorageMaster.persistTLVStorage(
          call LastSlave.get(), i2c_msg);
      }
    }

    if (error != SUCCESS){
      delete_toast_tlv_entry_response_msg_t* responsePl = (delete_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t)));
      responsePl->error = EINVAL;
      call DeleteToastTlvEntryResponseSend.send(0, responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t));
    }
  }

  event void DeleteToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }



  event message_t* AddToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: AddToastTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        } else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: AddToastTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondAddToastTlvEntry(){
    add_toast_tlv_entry_cmd_msg_t* commandPl = (add_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(add_toast_tlv_entry_cmd_msg_t)));
    error_t err = SUCCESS;
    tlv_entry_t* e;
//    uint8_t offset = call TLVUtils.findEntry(commandPl->tag,
//      commandPl->len, &e, tlvs);
//    if (offset != 0){
////      //tag exists, copy data into it
////      memcpy((void*)(&e->data), (void*)(commandPl->data), e->len);
//    }else{
    //add tag and initialize from commandPl
    uint8_t offset = call TLVUtils.addEntry(commandPl->tag, commandPl->len,
      (tlv_entry_t*)commandPl, tlvs, 0);
    if (offset == 0){
      err = ESIZE;
    }
//    }
    
    if (offset!=0){
      err = call I2CTLVStorageMaster.persistTLVStorage(call LastSlave.get(), i2c_msg);
    }
    if (err != SUCCESS){
      add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(add_toast_tlv_entry_response_msg_t)));
      responsePl->error = ESIZE;
      call AddToastTlvEntryResponseSend.send(0, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
    }
  }

  event void AddToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }



  event message_t* ReadToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: ReadToastTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        } else {
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: ReadToastTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadToastTlvEntry(){
    read_toast_tlv_entry_cmd_msg_t* commandPl = (read_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(read_toast_tlv_entry_cmd_msg_t)));
    read_toast_tlv_entry_response_msg_t* responsePl = (read_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_tlv_entry_response_msg_t)));
    tlv_entry_t* entry;
    uint8_t initOffset = 0;
    uint8_t offset = call TLVUtils.findEntry(commandPl->tag, 
      initOffset, &entry, tlvs);
//    printf("FE %x %u %p %p: %u\n", commandPl->tag, initOffset, &entry,
//      tlvs, offset);
    memcpy((void*)(&responsePl->tag), (void*)entry, entry->len+2);
    if (0 == offset){
      responsePl->error = EINVAL;
    } else{
      responsePl->error = SUCCESS;
    }
    call ReadToastTlvEntryResponseSend.send(0, responseMsg, sizeof(read_toast_tlv_entry_response_msg_t));
  }

  event void ReadToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  event message_t* WriteToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: WriteToastBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: WriteToastBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastBarcodeId(){
    write_toast_barcode_id_cmd_msg_t* commandPl = (write_toast_barcode_id_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(write_toast_barcode_id_cmd_msg_t)));
    tlv_entry_t* e;
    error_t error;
    uint8_t offset = call TLVUtils.findEntry(TAG_GLOBAL_ID, 0, &e, tlvs);
    //global ID present? update its data.
    if (offset != 0){
      memcpy(&(e->data), &(commandPl->barcodeId), TOAST_BARCODE_LEN);
    }else{
      //absent? create a new one.
      offset = call TLVUtils.addEntry(TAG_GLOBAL_ID, TOAST_BARCODE_LEN, 
        NULL, tlvs, 0);
      call TLVUtils.findEntry(TAG_GLOBAL_ID, offset, &e, tlvs);
      memcpy((&e->data), commandPl->barcodeId, TOAST_BARCODE_LEN);
      if (offset == 0){
        error = ESIZE;
      }else{
        error = call I2CTLVStorageMaster.persistTLVStorage(call LastSlave.get(), i2c_msg);
      }
    }
    if (error != SUCCESS){
      write_toast_barcode_id_response_msg_t* responsePl = (write_toast_barcode_id_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(write_toast_barcode_id_response_msg_t)));
      responsePl->error = error;
      call WriteToastBarcodeIdResponseSend.send(0, responseMsg, sizeof(write_toast_barcode_id_response_msg_t));
    }
  }

  event void WriteToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  event message_t* ReadToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: ReadToastBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: ReadToastBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadToastBarcodeId(){
    read_toast_barcode_id_response_msg_t* responsePl = (read_toast_barcode_id_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_barcode_id_response_msg_t)));
    error_t error = SUCCESS;
    tlv_entry_t* e;
    if (0 == call TLVUtils.findEntry(TAG_GLOBAL_ID, 0, &e, tlvs)){
      error = EINVAL;
    } else{
      memcpy(&(responsePl->barcodeId), &(e->data), TOAST_BARCODE_LEN);
    }
    responsePl->error = error;
    call ReadToastBarcodeIdResponseSend.send(0, responseMsg, sizeof(read_toast_barcode_id_response_msg_t));
  }

  event void ReadToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  event message_t* WriteToastAssignmentsCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX WTA\n");
    printfflush();
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: WriteToastAssignments");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: WriteToastAssignments");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastAssignments(){
    write_toast_assignments_cmd_msg_t* commandPl = (write_toast_assignments_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(write_toast_assignments_cmd_msg_t)));
    tlv_entry_t* e;
    error_t error;
    uint8_t offset; 
    printf("respondWriteToastAssignments");
    printf("find: %x %u %p %p\n", TAG_TOAST_ASSIGNMENTS, 0, &e, tlvs);
    offset = call TLVUtils.findEntry(TAG_TOAST_ASSIGNMENTS, 0, &e, tlvs);
    printf("offset: %u\n", offset);
    //assignments present? update its data.
    if (offset != 0){
      printf("updating at: %u (%p)\n", offset, e);
      printfflush();
      memcpy(&(e->data), &(commandPl->assignments),
        8*sizeof(sensor_assignment_t));
    }else{
      //absent? create a new one.
      offset = call TLVUtils.addEntry(TAG_TOAST_ASSIGNMENTS,
        8*sizeof(sensor_assignment_t), e, tlvs, 0);
      memcpy((&e->data), &(commandPl->assignments),
        8*sizeof(sensor_assignment_t));
      printf("Added at %u\n", offset);
      printfflush();
      if (offset == 0){
        error = ESIZE;
      }else{
        error = call I2CTLVStorageMaster.persistTLVStorage(call LastSlave.get(), i2c_msg);
      }
    }
    if (error != SUCCESS){
      write_toast_assignments_response_msg_t* responsePl = (write_toast_assignments_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(write_toast_assignments_response_msg_t)));
      responsePl->error = error;
      call WriteToastAssignmentsResponseSend.send(0, 
        responseMsg,
        sizeof(write_toast_assignments_response_msg_t));
    }
  }

  event void WriteToastAssignmentsResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  
}
