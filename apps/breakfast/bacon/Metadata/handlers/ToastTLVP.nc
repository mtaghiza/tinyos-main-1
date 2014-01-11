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

  uses interface Receive as ReadToastTlvCmdReceive;
  uses interface Receive as WriteToastTlvCmdReceive;
  uses interface Receive as DeleteToastTlvEntryCmdReceive;
  uses interface Receive as AddToastTlvEntryCmdReceive;
  uses interface Receive as ReadToastTlvEntryCmdReceive;

  uses interface AMSend as ReadToastTlvResponseSend;
  uses interface AMSend as WriteToastTlvResponseSend;
  uses interface AMSend as DeleteToastTlvEntryResponseSend;
  uses interface AMSend as AddToastTlvEntryResponseSend;
  uses interface AMSend as ReadToastTlvEntryResponseSend;

  uses interface AMSend as WriteToastVersionResponseSend;
  uses interface AMSend as WriteToastAssignmentsResponseSend;
  uses interface AMSend as WriteToastBarcodeIdResponseSend;

  uses interface AMSend as ReadToastVersionResponseSend;
  uses interface AMSend as ReadToastAssignmentsResponseSend;
  uses interface AMSend as ReadToastBarcodeIdResponseSend;

} implementation {
  am_addr_t cmdSource;

  message_t* responseMsg = NULL;
  message_t* cmdMsg = NULL;

  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;

  void* tlvs;
  am_id_t currentCommandType;
  error_t loadTLVError;

  task void handleLoaded();

  task void respondReadToastTlv();
  task void respondWriteToastTlv();
  task void respondDeleteToastTlvEntry();
  task void respondAddToastTlvEntry();
  task void respondReadToastTlvEntry();

  void cleanup(){
    if (responseMsg != NULL){
      call Pool.put(responseMsg);
      responseMsg = NULL;
    }
    if (cmdMsg != NULL){
      call Pool.put(cmdMsg);
      cmdMsg = NULL;
    }
    currentCommandType = 0;
  }

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
//    printf("HL err: %x %x\n", loadTLVError, currentCommandType);
//    printfflush();
    if (loadTLVError == SUCCESS){
      switch (currentCommandType){
        case AM_READ_TOAST_TLV_CMD_MSG:
          post respondReadToastTlv();
          break;
        case AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG:
          post respondDeleteToastTlvEntry();
          break;
        case AM_ADD_TOAST_TLV_ENTRY_CMD_MSG:
          post respondAddToastTlvEntry();
          break;
        case AM_READ_TOAST_TLV_ENTRY_CMD_MSG:
          post respondReadToastTlvEntry();
          break;
        default:
          printf("Unknown command %x\n", currentCommandType);
      }
    } else {
      read_toast_tlv_response_msg_t* responsePl = 
        (read_toast_tlv_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_tlv_response_msg_t)));
      error_t err;
      responsePl->error = loadTLVError;
      switch (currentCommandType){
        case AM_READ_TOAST_TLV_CMD_MSG:
          call ReadToastTlvResponseSend.send(cmdSource, responseMsg, 
            sizeof(read_toast_tlv_response_msg_t));
          break;
        case AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG:
          call DeleteToastTlvEntryResponseSend.send(cmdSource, responseMsg, 
            sizeof(delete_toast_tlv_entry_response_msg_t));
          break;
        case AM_ADD_TOAST_TLV_ENTRY_CMD_MSG:
          call AddToastTlvEntryResponseSend.send(cmdSource, responseMsg, 
            sizeof(add_toast_tlv_entry_response_msg_t));
          break;
        case AM_READ_TOAST_TLV_ENTRY_CMD_MSG:
//          err = call ReadToastTlvEntryResponseSend.send(0, responseMsg, 
//            sizeof(read_toast_tlv_entry_response_msg_t));
          err = call ReadToastVersionResponseSend.send(cmdSource, responseMsg, 
            sizeof(read_toast_version_response_msg_t));
//          printf("read entry error response: %x\n", err);
//          printfflush();
          break;
        default:
          printf("Unrecognized current command: %x\n",
            currentCommandType);
          printfflush();
          break;
      }
      currentCommandType = 0;
    }
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){
    add_toast_tlv_entry_cmd_msg_t* commandPl = (add_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(add_toast_tlv_entry_cmd_msg_t)));
    add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(add_toast_tlv_entry_response_msg_t)));
    responsePl->error = error;
    switch(currentCommandType){
      case AM_ADD_TOAST_TLV_ENTRY_CMD_MSG:
        switch(commandPl->tag){
          case TAG_VERSION:
            call WriteToastVersionResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
            break;
          case TAG_TOAST_ASSIGNMENTS:
            call WriteToastAssignmentsResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
            break;
          case TAG_GLOBAL_ID:
            call WriteToastBarcodeIdResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
            break;
          default:
            call AddToastTlvEntryResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
            break;
        }
        break;
      case AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG:
        call DeleteToastTlvEntryResponseSend.send(cmdSource, responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t));
        break;
      case AM_WRITE_TOAST_TLV_CMD_MSG:
        call WriteToastTlvResponseSend.send(cmdSource, responseMsg, sizeof(write_toast_tlv_response_msg_t));
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
//        printf("LastSlave:%u\n", call LastSlave.get());
//        printfflush();
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          responseMsg = call Pool.get();
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          void* pl;
          responseMsg = call Pool.get();
          call Packet.clear(responseMsg);
          pl = call Packet.getPayload(responseMsg, TOSH_DATA_LENGTH);
          if (pl != NULL){
            memset(pl, 0, TOSH_DATA_LENGTH);
          }
          cmdMsg = msg_;
          cmdSource = call AMPacket.source(msg_);
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
    err = call ReadToastTlvResponseSend.send(cmdSource, responseMsg, sizeof(read_toast_tlv_response_msg_t));
  }

  event void ReadToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }

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
          responseMsg = call Pool.get();
          //TODO: should be handled differently
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          void* pl;
          responseMsg = call Pool.get();
          call Packet.clear(responseMsg);
          pl = call Packet.getPayload(responseMsg, TOSH_DATA_LENGTH);
          if (pl != NULL){
            memset(pl, 0, TOSH_DATA_LENGTH);
          }
          cmdMsg = msg_;
          cmdSource = call AMPacket.source(msg_);
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
      call WriteToastTlvResponseSend.send(cmdSource, responseMsg, sizeof(write_toast_tlv_response_msg_t));
    }
  }

  event void WriteToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }

  message_t* tlvSetup(message_t* msg_){
    if (cmdMsg != NULL){
      printf("RX: %x BUSY!\n", currentCommandType);
      printfflush();
      return msg_;
    }else{
      currentCommandType = call AMPacket.type(msg_);
      if ((call Pool.size()) >= 2){
//        printf("LastSlave:%u\n", call LastSlave.get());
//        printfflush();
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          responseMsg = call Pool.get();
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          void* pl;
          responseMsg = call Pool.get();
          call Packet.clear(responseMsg);
          pl = call Packet.getPayload(responseMsg, TOSH_DATA_LENGTH);
          if (pl != NULL){
            memset(pl, 0, TOSH_DATA_LENGTH);
          }
          cmdMsg = msg_;
          cmdSource = call AMPacket.source(msg_);
          post loadToastTLVStorage();
          return ret;
        }
      }else{
        printf("RX: %x Pool empty!\n", currentCommandType);
        printfflush();
        return msg_;
      }
    }
  }

  event message_t* DeleteToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    return tlvSetup(msg_);
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
      call DeleteToastTlvEntryResponseSend.send(cmdSource, responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t));
    }
  }

  event void DeleteToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }

  event message_t* AddToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    return tlvSetup(msg_);
  }

  task void respondAddToastTlvEntry(){
    add_toast_tlv_entry_cmd_msg_t* commandPl = (add_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(add_toast_tlv_entry_cmd_msg_t)));
    error_t err = SUCCESS;
    tlv_entry_t* e;
    //add tag and initialize from commandPl
    uint8_t offset = call TLVUtils.findEntry(commandPl->tag, 0, &e,
      tlvs);

    if (offset != 0){
      err = call TLVUtils.deleteEntry(offset, tlvs);
    }

    if (err == SUCCESS){
      offset = call TLVUtils.addEntry(commandPl->tag, commandPl->len,
        (tlv_entry_t*)commandPl, tlvs, 0);
      if (offset == 0){
        err = ESIZE;
      } else {
        err = call I2CTLVStorageMaster.persistTLVStorage(call LastSlave.get(), i2c_msg);
      }
    }

    if (err != SUCCESS){
      add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(add_toast_tlv_entry_response_msg_t)));
      responsePl->error = err;
      switch(commandPl->tag){
        case TAG_VERSION:
          call WriteToastVersionResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
          break;
        case TAG_TOAST_ASSIGNMENTS:
          call WriteToastAssignmentsResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
          break;
        case TAG_GLOBAL_ID:
          call WriteToastBarcodeIdResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
          break;
        default:
          call AddToastTlvEntryResponseSend.send(cmdSource, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
          break;
      }
    }
  }

  event void AddToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }

  event message_t* ReadToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    return tlvSetup(msg_);
  }

  task void respondReadToastTlvEntry(){
    read_toast_tlv_entry_cmd_msg_t* commandPl = (read_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(cmdMsg, sizeof(read_toast_tlv_entry_cmd_msg_t)));
    read_toast_tlv_entry_response_msg_t* responsePl = (read_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_toast_tlv_entry_response_msg_t)));
    tlv_entry_t* entry;
    uint8_t initOffset = 0;
    uint8_t offset = call TLVUtils.findEntry(commandPl->tag, 
      initOffset, &entry, tlvs);
    if (0 == offset){
      responsePl->error = EINVAL;
    } else{
      memcpy((void*)(&responsePl->tag), (void*)entry, entry->len+2);
      responsePl->error = SUCCESS;
    }
    switch(commandPl->tag){
      case TAG_VERSION:
        call ReadToastVersionResponseSend.send(cmdSource, responseMsg, 
          sizeof(read_toast_version_response_msg_t));
        break;
      case TAG_GLOBAL_ID:
        printf("barcode\n");
        printfflush();
        call ReadToastBarcodeIdResponseSend.send(cmdSource, responseMsg, 
          sizeof(read_toast_barcode_id_response_msg_t));
        break;
      case TAG_TOAST_ASSIGNMENTS:
        printf("Assignments\n");
        printfflush();
        call ReadToastAssignmentsResponseSend.send(cmdSource, responseMsg,
          sizeof(read_toast_assignments_response_msg_t));
        break;
      default:
        printf("generic\n");
        printfflush();
        call ReadToastTlvEntryResponseSend.send(cmdSource, responseMsg, sizeof(read_toast_tlv_entry_response_msg_t));
        break;
    }
  }

  event void ReadToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    printf("Response sent\n");
    printfflush();
    cleanup();
  }

  event void ReadToastAssignmentsResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }
  event void ReadToastVersionResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }
  event void ReadToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }

  event void WriteToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }
  event void WriteToastVersionResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }
  event void WriteToastAssignmentsResponseSend.sendDone(message_t* msg, 
      error_t error){
    cleanup();
  }


}
////For edit entry (if we want that)
//    uint8_t offset = call TLVUtils.findEntry(commandPl->tag,
//      commandPl->len, &e, tlvs);
//    if (offset != 0){
////      //tag exists, copy data into it
////      memcpy((void*)(&e->data), (void*)(commandPl->data), e->len);
//    }else{
//      err = EINVAL;
//    }
