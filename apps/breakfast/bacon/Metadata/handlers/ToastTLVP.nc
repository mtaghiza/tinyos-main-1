 #include "I2CCom.h"
 #include "I2CTLVStorage.h"
module ToastTLVP{
  uses interface Packet;
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
  uses interface I2CTLVStorageMaster;

  uses interface Receive as ReadToastBarcodeIdCmdReceive;
  uses interface Receive as WriteToastBarcodeIdCmdReceive;
  uses interface Receive as ReadToastAssignmentsCmdReceive;
  uses interface Receive as WriteToastAssignmentsCmdReceive;
  uses interface Receive as ReadToastTlvCmdReceive;
  uses interface Receive as WriteToastTlvCmdReceive;
  uses interface Receive as DeleteToastTlvEntryCmdReceive;
  uses interface Receive as AddToastTlvEntryCmdReceive;
  uses interface AMSend as ReadToastBarcodeIdResponseSend;
  uses interface AMSend as WriteToastBarcodeIdResponseSend;
  uses interface AMSend as ReadToastAssignmentsResponseSend;
  uses interface AMSend as WriteToastAssignmentsResponseSend;
  uses interface AMSend as ReadToastTlvResponseSend;
  uses interface AMSend as WriteToastTlvResponseSend;
  uses interface AMSend as DeleteToastTlvEntryResponseSend;
  uses interface AMSend as AddToastTlvEntryResponseSend;
} implementation {
  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;

  message_t* ReadToastBarcodeId_cmd_msg = NULL;
  message_t* ReadToastBarcodeId_response_msg = NULL;
  task void respondReadToastBarcodeId();

  event message_t* ReadToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadToastBarcodeId_cmd_msg != NULL){
      printf("RX: ReadToastBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadToastBarcodeId_response_msg = call Pool.get();
        ReadToastBarcodeId_cmd_msg = msg_;
        post respondReadToastBarcodeId();
        return ret;
      }else{
        printf("RX: ReadToastBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadToastBarcodeId(){
//    read_toast_barcode_id_cmd_msg_t* commandPl = (read_toast_barcode_id_cmd_msg_t*)(call Packet.getPayload(ReadToastBarcodeId_cmd_msg, sizeof(read_toast_barcode_id_cmd_msg_t)));
    read_toast_barcode_id_response_msg_t* responsePl = (read_toast_barcode_id_response_msg_t*)(call Packet.getPayload(ReadToastBarcodeId_response_msg, sizeof(read_toast_barcode_id_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadToastBarcodeIdResponseSend.send(0, ReadToastBarcodeId_response_msg, sizeof(read_toast_barcode_id_response_msg_t));
  }

  event void ReadToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadToastBarcodeId_response_msg);
    call Pool.put(ReadToastBarcodeId_cmd_msg);
    ReadToastBarcodeId_cmd_msg = NULL;
    ReadToastBarcodeId_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastBarcodeId_cmd_msg = NULL;
  message_t* WriteToastBarcodeId_response_msg = NULL;
  task void respondWriteToastBarcodeId();

  event message_t* WriteToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (WriteToastBarcodeId_cmd_msg != NULL){
      printf("RX: WriteToastBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastBarcodeId_response_msg = call Pool.get();
        WriteToastBarcodeId_cmd_msg = msg_;
        post respondWriteToastBarcodeId();
        return ret;
      }else{
        printf("RX: WriteToastBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastBarcodeId(){
//    write_toast_barcode_id_cmd_msg_t* commandPl = (write_toast_barcode_id_cmd_msg_t*)(call Packet.getPayload(WriteToastBarcodeId_cmd_msg, sizeof(write_toast_barcode_id_cmd_msg_t)));
    write_toast_barcode_id_response_msg_t* responsePl = (write_toast_barcode_id_response_msg_t*)(call Packet.getPayload(WriteToastBarcodeId_response_msg, sizeof(write_toast_barcode_id_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteToastBarcodeIdResponseSend.send(0, WriteToastBarcodeId_response_msg, sizeof(write_toast_barcode_id_response_msg_t));
  }

  event void WriteToastBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(WriteToastBarcodeId_response_msg);
    call Pool.put(WriteToastBarcodeId_cmd_msg);
    WriteToastBarcodeId_cmd_msg = NULL;
    WriteToastBarcodeId_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadToastAssignments_cmd_msg = NULL;
  message_t* ReadToastAssignments_response_msg = NULL;
  task void respondReadToastAssignments();

  event message_t* ReadToastAssignmentsCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadToastAssignments_cmd_msg != NULL){
      printf("RX: ReadToastAssignments");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadToastAssignments_response_msg = call Pool.get();
        ReadToastAssignments_cmd_msg = msg_;
        post respondReadToastAssignments();
        return ret;
      }else{
        printf("RX: ReadToastAssignments");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadToastAssignments(){
//    read_toast_assignments_cmd_msg_t* commandPl = (read_toast_assignments_cmd_msg_t*)(call Packet.getPayload(ReadToastAssignments_cmd_msg, sizeof(read_toast_assignments_cmd_msg_t)));
    read_toast_assignments_response_msg_t* responsePl = (read_toast_assignments_response_msg_t*)(call Packet.getPayload(ReadToastAssignments_response_msg, sizeof(read_toast_assignments_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadToastAssignmentsResponseSend.send(0, ReadToastAssignments_response_msg, sizeof(read_toast_assignments_response_msg_t));
  }

  event void ReadToastAssignmentsResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadToastAssignments_response_msg);
    call Pool.put(ReadToastAssignments_cmd_msg);
    ReadToastAssignments_cmd_msg = NULL;
    ReadToastAssignments_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastAssignments_cmd_msg = NULL;
  message_t* WriteToastAssignments_response_msg = NULL;
  task void respondWriteToastAssignments();

  event message_t* WriteToastAssignmentsCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (WriteToastAssignments_cmd_msg != NULL){
      printf("RX: WriteToastAssignments");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastAssignments_response_msg = call Pool.get();
        WriteToastAssignments_cmd_msg = msg_;
        post respondWriteToastAssignments();
        return ret;
      }else{
        printf("RX: WriteToastAssignments");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastAssignments(){
//    write_toast_assignments_cmd_msg_t* commandPl = (write_toast_assignments_cmd_msg_t*)(call Packet.getPayload(WriteToastAssignments_cmd_msg, sizeof(write_toast_assignments_cmd_msg_t)));
    write_toast_assignments_response_msg_t* responsePl = (write_toast_assignments_response_msg_t*)(call Packet.getPayload(WriteToastAssignments_response_msg, sizeof(write_toast_assignments_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteToastAssignmentsResponseSend.send(0, WriteToastAssignments_response_msg, sizeof(write_toast_assignments_response_msg_t));
  }

  event void WriteToastAssignmentsResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(WriteToastAssignments_response_msg);
    call Pool.put(WriteToastAssignments_cmd_msg);
    WriteToastAssignments_cmd_msg = NULL;
    WriteToastAssignments_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  message_t* ReadToastTlv_cmd_msg = NULL;
  message_t* ReadToastTlv_response_msg = NULL;
  error_t readToastTLVError = FAIL;

  task void respondReadToastTlv();
  task void reportReadToastTLVError();

  task void loadToastTLVStorage(){
    readToastTLVError = call I2CTLVStorageMaster.loadTLVStorage((call
    LastSlave.get()),
      i2c_msg);
    if (readToastTLVError  != SUCCESS){
      post reportReadToastTLVError();
    }
  }

  event void I2CTLVStorageMaster.loaded(error_t error, i2c_message_t* msg_){
    readToastTLVError = error;
    if (error != SUCCESS){
      post reportReadToastTLVError();
    } else{
      post respondReadToastTlv();
    }
  }

  event void I2CTLVStorageMaster.persisted(error_t error, i2c_message_t* msg){
  }

  task void reportReadToastTLVError(){
    read_toast_tlv_response_msg_t* responsePl = (read_toast_tlv_response_msg_t*)(call Packet.getPayload(ReadToastTlv_response_msg, sizeof(read_toast_tlv_response_msg_t)));
    responsePl->error = readToastTLVError;
    call ReadToastTlvResponseSend.send(0, ReadToastTlv_response_msg, sizeof(read_toast_tlv_response_msg_t));
  }

  event message_t* ReadToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadToastTlv_cmd_msg != NULL){
      printf("RX: ReadToastTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if ((call LastSlave.get())==0){
          readToastTLVError = EOFF;
          post reportReadToastTLVError();
          return msg_;
        } else{
          message_t* ret = call Pool.get();
          ReadToastTlv_response_msg = call Pool.get();
          ReadToastTlv_cmd_msg = msg_;
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
//    read_toast_tlv_cmd_msg_t* commandPl = (read_toast_tlv_cmd_msg_t*)(call Packet.getPayload(ReadToastTlv_cmd_msg, sizeof(read_toast_tlv_cmd_msg_t)));
    read_toast_tlv_response_msg_t* responsePl = (read_toast_tlv_response_msg_t*)(call Packet.getPayload(ReadToastTlv_response_msg, sizeof(read_toast_tlv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadToastTlvResponseSend.send(0, ReadToastTlv_response_msg, sizeof(read_toast_tlv_response_msg_t));
  }

  event void ReadToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadToastTlv_response_msg);
    call Pool.put(ReadToastTlv_cmd_msg);
    ReadToastTlv_cmd_msg = NULL;
    ReadToastTlv_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastTlv_cmd_msg = NULL;
  message_t* WriteToastTlv_response_msg = NULL;
  task void respondWriteToastTlv();

  event message_t* WriteToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (WriteToastTlv_cmd_msg != NULL){
      printf("RX: WriteToastTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastTlv_response_msg = call Pool.get();
        WriteToastTlv_cmd_msg = msg_;
        post respondWriteToastTlv();
        return ret;
      }else{
        printf("RX: WriteToastTlv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteToastTlv(){
//    write_toast_tlv_cmd_msg_t* commandPl = (write_toast_tlv_cmd_msg_t*)(call Packet.getPayload(WriteToastTlv_cmd_msg, sizeof(write_toast_tlv_cmd_msg_t)));
    write_toast_tlv_response_msg_t* responsePl = (write_toast_tlv_response_msg_t*)(call Packet.getPayload(WriteToastTlv_response_msg, sizeof(write_toast_tlv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteToastTlvResponseSend.send(0, WriteToastTlv_response_msg, sizeof(write_toast_tlv_response_msg_t));
  }

  event void WriteToastTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(WriteToastTlv_response_msg);
    call Pool.put(WriteToastTlv_cmd_msg);
    WriteToastTlv_cmd_msg = NULL;
    WriteToastTlv_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* DeleteToastTlvEntry_cmd_msg = NULL;
  message_t* DeleteToastTlvEntry_response_msg = NULL;
  task void respondDeleteToastTlvEntry();

  event message_t* DeleteToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (DeleteToastTlvEntry_cmd_msg != NULL){
      printf("RX: DeleteToastTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        DeleteToastTlvEntry_response_msg = call Pool.get();
        DeleteToastTlvEntry_cmd_msg = msg_;
        post respondDeleteToastTlvEntry();
        return ret;
      }else{
        printf("RX: DeleteToastTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondDeleteToastTlvEntry(){
//    delete_toast_tlv_entry_cmd_msg_t* commandPl = (delete_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(DeleteToastTlvEntry_cmd_msg, sizeof(delete_toast_tlv_entry_cmd_msg_t)));
    delete_toast_tlv_entry_response_msg_t* responsePl = (delete_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(DeleteToastTlvEntry_response_msg, sizeof(delete_toast_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call DeleteToastTlvEntryResponseSend.send(0, DeleteToastTlvEntry_response_msg, sizeof(delete_toast_tlv_entry_response_msg_t));
  }

  event void DeleteToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(DeleteToastTlvEntry_response_msg);
    call Pool.put(DeleteToastTlvEntry_cmd_msg);
    DeleteToastTlvEntry_cmd_msg = NULL;
    DeleteToastTlvEntry_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }

  message_t* AddToastTlvEntry_cmd_msg = NULL;
  message_t* AddToastTlvEntry_response_msg = NULL;
  task void respondAddToastTlvEntry();

  event message_t* AddToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (AddToastTlvEntry_cmd_msg != NULL){
      printf("RX: AddToastTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        AddToastTlvEntry_response_msg = call Pool.get();
        AddToastTlvEntry_cmd_msg = msg_;
        post respondAddToastTlvEntry();
        return ret;
      }else{
        printf("RX: AddToastTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondAddToastTlvEntry(){
//    add_toast_tlv_entry_cmd_msg_t* commandPl = (add_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(AddToastTlvEntry_cmd_msg, sizeof(add_toast_tlv_entry_cmd_msg_t)));
    add_toast_tlv_entry_response_msg_t* responsePl = (add_toast_tlv_entry_response_msg_t*)(call Packet.getPayload(AddToastTlvEntry_response_msg, sizeof(add_toast_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call AddToastTlvEntryResponseSend.send(0, AddToastTlvEntry_response_msg, sizeof(add_toast_tlv_entry_response_msg_t));
  }

  event void AddToastTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(AddToastTlvEntry_response_msg);
    call Pool.put(AddToastTlvEntry_cmd_msg);
    AddToastTlvEntry_cmd_msg = NULL;
    AddToastTlvEntry_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  
}
