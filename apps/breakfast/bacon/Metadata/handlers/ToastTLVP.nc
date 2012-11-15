 #include "I2CCom.h"
 #include "I2CTLVStorage.h"
module ToastTLVP{
  uses interface Packet;
  uses interface AMPacket;
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
  uses interface I2CTLVStorageMaster;

//  uses interface Receive as ReadToastBarcodeIdCmdReceive;
//  uses interface Receive as WriteToastBarcodeIdCmdReceive;
//  uses interface Receive as ReadToastAssignmentsCmdReceive;
//  uses interface Receive as WriteToastAssignmentsCmdReceive;
  uses interface Receive as ReadToastTlvCmdReceive;
  uses interface Receive as WriteToastTlvCmdReceive;
  uses interface Receive as DeleteToastTlvEntryCmdReceive;
  uses interface Receive as AddToastTlvEntryCmdReceive;
  uses interface Receive as ReadToastTlvEntryCmdReceive;
//  uses interface AMSend as ReadToastBarcodeIdResponseSend;
//  uses interface AMSend as WriteToastBarcodeIdResponseSend;
//  uses interface AMSend as ReadToastAssignmentsResponseSend;
//  uses interface AMSend as WriteToastAssignmentsResponseSend;
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
    write_toast_tlv_response_msg_t* responsePl = (write_toast_tlv_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(write_toast_tlv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteToastTlvResponseSend.send(0, responseMsg, sizeof(write_toast_tlv_response_msg_t));
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
  task void respondDeleteToastTlvEntry();

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
          post respondDeleteToastTlvEntry();
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
    delete_toast_tlv_entry_response_msg_t* responsePl = (delete_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call DeleteToastTlvEntryResponseSend.send(0, responseMsg, sizeof(delete_toast_tlv_entry_response_msg_t));
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


  task void respondAddToastTlvEntry();

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
          post respondAddToastTlvEntry();
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
    add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(add_toast_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call AddToastTlvEntryResponseSend.send(0, responseMsg, sizeof(add_toast_tlv_entry_response_msg_t));
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
          post respondReadToastTlvEntry();
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
    //TODO: other processing logic
    responsePl->error = FAIL;
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

  
}
