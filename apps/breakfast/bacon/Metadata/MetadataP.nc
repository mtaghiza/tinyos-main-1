
 #include "printf.h"
 #include "decodeError.h"

module MetadataP{
  uses interface Boot;
  uses interface Packet;
  uses interface SplitControl as SerialSplitControl;
  uses interface Pool<message_t>;

  uses interface Leds;
  
//Begin Auto-generated used interfaces (see genUsedInterfaces.sh)
//Receive
uses interface Receive as ReadIvCmdReceive;
uses interface Receive as ReadMfrIdCmdReceive;
uses interface Receive as ReadBaconBarcodeIdCmdReceive;
uses interface Receive as WriteBaconBarcodeIdCmdReceive;
uses interface Receive as ResetBaconCmdReceive;
uses interface Receive as ReadBaconTlvCmdReceive;
uses interface Receive as WriteBaconTlvCmdReceive;
uses interface Receive as DeleteBaconTlvEntryCmdReceive;
uses interface Receive as AddBaconTlvEntryCmdReceive;
//Send
uses interface AMSend as ReadIvResponseSend;
uses interface AMSend as ReadMfrIdResponseSend;
uses interface AMSend as ReadBaconBarcodeIdResponseSend;
uses interface AMSend as WriteBaconBarcodeIdResponseSend;
uses interface AMSend as ResetBaconResponseSend;
uses interface AMSend as ReadBaconTlvResponseSend;
uses interface AMSend as WriteBaconTlvResponseSend;
uses interface AMSend as DeleteBaconTlvEntryResponseSend;
uses interface AMSend as AddBaconTlvEntryResponseSend;
//End Auto-generated used interfaces
  
} implementation {
  enum {
    S_BOOTING ,
    S_READY
  };

  uint8_t state = S_BOOTING;

  event void Boot.booted(){
    call Leds.led0On();
    printf("Booted.\n");
    printfflush();
    call SerialSplitControl.start();
  }
  
  task void respondResetBacon();

  event void SerialSplitControl.startDone(error_t error){ 
    state = S_READY;
    post respondResetBacon();
  }


  event void SerialSplitControl.stopDone(error_t error){}

//Begin Auto-generated message stubs (see genStubs.sh)

  message_t* ReadBaconBarcodeId_cmd_msg = NULL;
  message_t* ReadBaconBarcodeId_response_msg = NULL;
  task void respondReadBaconBarcodeId();

  event message_t* ReadBaconBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadBaconBarcodeId_cmd_msg != NULL){
      printf("RX: ReadBaconBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadBaconBarcodeId_response_msg = call Pool.get();
        ReadBaconBarcodeId_cmd_msg = msg_;
        post respondReadBaconBarcodeId();
        return ret;
      }else{
        printf("RX: ReadBaconBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadBaconBarcodeId(){
//    read_bacon_barcode_id_cmd_msg_t* commandPl = (read_bacon_barcode_id_cmd_msg_t*)(call Packet.getPayload(ReadBaconBarcodeId_cmd_msg, sizeof(read_bacon_barcode_id_cmd_msg_t)));
    read_bacon_barcode_id_response_msg_t* responsePl = (read_bacon_barcode_id_response_msg_t*)(call Packet.getPayload(ReadBaconBarcodeId_response_msg, sizeof(read_bacon_barcode_id_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadBaconBarcodeIdResponseSend.send(0, ReadBaconBarcodeId_response_msg, sizeof(read_bacon_barcode_id_response_msg_t));
  }

  event void ReadBaconBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadBaconBarcodeId_response_msg);
    call Pool.put(ReadBaconBarcodeId_cmd_msg);
    ReadBaconBarcodeId_cmd_msg = NULL;
    ReadBaconBarcodeId_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteBaconBarcodeId_cmd_msg = NULL;
  message_t* WriteBaconBarcodeId_response_msg = NULL;
  task void respondWriteBaconBarcodeId();

  event message_t* WriteBaconBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (WriteBaconBarcodeId_cmd_msg != NULL){
      printf("RX: WriteBaconBarcodeId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteBaconBarcodeId_response_msg = call Pool.get();
        WriteBaconBarcodeId_cmd_msg = msg_;
        post respondWriteBaconBarcodeId();
        return ret;
      }else{
        printf("RX: WriteBaconBarcodeId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteBaconBarcodeId(){
//    write_bacon_barcode_id_cmd_msg_t* commandPl = (write_bacon_barcode_id_cmd_msg_t*)(call Packet.getPayload(WriteBaconBarcodeId_cmd_msg, sizeof(write_bacon_barcode_id_cmd_msg_t)));
    write_bacon_barcode_id_response_msg_t* responsePl = (write_bacon_barcode_id_response_msg_t*)(call Packet.getPayload(WriteBaconBarcodeId_response_msg, sizeof(write_bacon_barcode_id_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteBaconBarcodeIdResponseSend.send(0, WriteBaconBarcodeId_response_msg, sizeof(write_bacon_barcode_id_response_msg_t));
  }

  event void WriteBaconBarcodeIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(WriteBaconBarcodeId_response_msg);
    call Pool.put(WriteBaconBarcodeId_cmd_msg);
    WriteBaconBarcodeId_cmd_msg = NULL;
    WriteBaconBarcodeId_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }



  message_t* ReadBaconTlv_cmd_msg = NULL;
  message_t* ReadBaconTlv_response_msg = NULL;
  task void respondReadBaconTlv();

  event message_t* ReadBaconTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadBaconTlv_cmd_msg != NULL){
      printf("RX: ReadBaconTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadBaconTlv_response_msg = call Pool.get();
        ReadBaconTlv_cmd_msg = msg_;
        post respondReadBaconTlv();
        return ret;
      }else{
        printf("RX: ReadBaconTlv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadBaconTlv(){
//    read_bacon_tlv_cmd_msg_t* commandPl = (read_bacon_tlv_cmd_msg_t*)(call Packet.getPayload(ReadBaconTlv_cmd_msg, sizeof(read_bacon_tlv_cmd_msg_t)));
    read_bacon_tlv_response_msg_t* responsePl = (read_bacon_tlv_response_msg_t*)(call Packet.getPayload(ReadBaconTlv_response_msg, sizeof(read_bacon_tlv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadBaconTlvResponseSend.send(0, ReadBaconTlv_response_msg, sizeof(read_bacon_tlv_response_msg_t));
  }

  event void ReadBaconTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadBaconTlv_response_msg);
    call Pool.put(ReadBaconTlv_cmd_msg);
    ReadBaconTlv_cmd_msg = NULL;
    ReadBaconTlv_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }



  message_t* WriteBaconTlv_cmd_msg = NULL;
  message_t* WriteBaconTlv_response_msg = NULL;
  task void respondWriteBaconTlv();

  event message_t* WriteBaconTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (WriteBaconTlv_cmd_msg != NULL){
      printf("RX: WriteBaconTlv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteBaconTlv_response_msg = call Pool.get();
        WriteBaconTlv_cmd_msg = msg_;
        post respondWriteBaconTlv();
        return ret;
      }else{
        printf("RX: WriteBaconTlv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondWriteBaconTlv(){
//    write_bacon_tlv_cmd_msg_t* commandPl = (write_bacon_tlv_cmd_msg_t*)(call Packet.getPayload(WriteBaconTlv_cmd_msg, sizeof(write_bacon_tlv_cmd_msg_t)));
    write_bacon_tlv_response_msg_t* responsePl = (write_bacon_tlv_response_msg_t*)(call Packet.getPayload(WriteBaconTlv_response_msg, sizeof(write_bacon_tlv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call WriteBaconTlvResponseSend.send(0, WriteBaconTlv_response_msg, sizeof(write_bacon_tlv_response_msg_t));
  }

  event void WriteBaconTlvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(WriteBaconTlv_response_msg);
    call Pool.put(WriteBaconTlv_cmd_msg);
    WriteBaconTlv_cmd_msg = NULL;
    WriteBaconTlv_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* DeleteBaconTlvEntry_cmd_msg = NULL;
  message_t* DeleteBaconTlvEntry_response_msg = NULL;
  task void respondDeleteBaconTlvEntry();

  event message_t* DeleteBaconTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (DeleteBaconTlvEntry_cmd_msg != NULL){
      printf("RX: DeleteBaconTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        DeleteBaconTlvEntry_response_msg = call Pool.get();
        DeleteBaconTlvEntry_cmd_msg = msg_;
        post respondDeleteBaconTlvEntry();
        return ret;
      }else{
        printf("RX: DeleteBaconTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondDeleteBaconTlvEntry(){
//    delete_bacon_tlv_entry_cmd_msg_t* commandPl = (delete_bacon_tlv_entry_cmd_msg_t*)(call Packet.getPayload(DeleteBaconTlvEntry_cmd_msg, sizeof(delete_bacon_tlv_entry_cmd_msg_t)));
    delete_bacon_tlv_entry_response_msg_t* responsePl = (delete_bacon_tlv_entry_response_msg_t*)(call Packet.getPayload(DeleteBaconTlvEntry_response_msg, sizeof(delete_bacon_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call DeleteBaconTlvEntryResponseSend.send(0, DeleteBaconTlvEntry_response_msg, sizeof(delete_bacon_tlv_entry_response_msg_t));
  }

  event void DeleteBaconTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(DeleteBaconTlvEntry_response_msg);
    call Pool.put(DeleteBaconTlvEntry_cmd_msg);
    DeleteBaconTlvEntry_cmd_msg = NULL;
    DeleteBaconTlvEntry_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* AddBaconTlvEntry_cmd_msg = NULL;
  message_t* AddBaconTlvEntry_response_msg = NULL;
  task void respondAddBaconTlvEntry();

  event message_t* AddBaconTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (AddBaconTlvEntry_cmd_msg != NULL){
      printf("RX: AddBaconTlvEntry");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        AddBaconTlvEntry_response_msg = call Pool.get();
        AddBaconTlvEntry_cmd_msg = msg_;
        post respondAddBaconTlvEntry();
        return ret;
      }else{
        printf("RX: AddBaconTlvEntry");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondAddBaconTlvEntry(){
//    add_bacon_tlv_entry_cmd_msg_t* commandPl = (add_bacon_tlv_entry_cmd_msg_t*)(call Packet.getPayload(AddBaconTlvEntry_cmd_msg, sizeof(add_bacon_tlv_entry_cmd_msg_t)));
    add_bacon_tlv_entry_response_msg_t* responsePl = (add_bacon_tlv_entry_response_msg_t*)(call Packet.getPayload(AddBaconTlvEntry_response_msg, sizeof(add_bacon_tlv_entry_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call AddBaconTlvEntryResponseSend.send(0, AddBaconTlvEntry_response_msg, sizeof(add_bacon_tlv_entry_response_msg_t));
  }

  event void AddBaconTlvEntryResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(AddBaconTlvEntry_response_msg);
    call Pool.put(AddBaconTlvEntry_cmd_msg);
    AddBaconTlvEntry_cmd_msg = NULL;
    AddBaconTlvEntry_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }



//End auto-generated message stubs

//Begin completed implementations
  //Reset Bacon
  message_t* ResetBacon_response_msg = NULL;
  
  task void resetBacon(){
    WDTCTL = 0;
  }

  event message_t* ResetBaconCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    post resetBacon();
    return msg_;
  }

  task void respondResetBacon(){
    if (call Pool.size()){
      ResetBacon_response_msg = call Pool.get(); 
      {
        reset_bacon_response_msg_t* responsePl = (reset_bacon_response_msg_t*)(call Packet.getPayload(ResetBacon_response_msg, sizeof(reset_bacon_response_msg_t)));
        responsePl->error = SUCCESS;
        call ResetBaconResponseSend.send(0, ResetBacon_response_msg,
          sizeof(reset_bacon_response_msg_t));
      }
    }
  }

  event void ResetBaconResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ResetBacon_response_msg);
    ResetBacon_response_msg = NULL;
    call Leds.led0Off();
  }
  
  //Read bacon IV
  message_t* ReadIv_cmd_msg = NULL;
  message_t* ReadIv_response_msg = NULL;
  task void respondReadIv();

  event message_t* ReadIvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadIv_cmd_msg != NULL){
      printf("RX: ReadIv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadIv_response_msg = call Pool.get();
        ReadIv_cmd_msg = msg_;
        post respondReadIv();
        return ret;
      }else{
        printf("RX: ReadIv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadIv(){
//    read_iv_cmd_msg_t* commandPl = (read_iv_cmd_msg_t*)(call Packet.getPayload(ReadIv_cmd_msg, sizeof(read_iv_cmd_msg_t)));
    read_iv_response_msg_t* responsePl = (read_iv_response_msg_t*)(call Packet.getPayload(ReadIv_response_msg, sizeof(read_iv_response_msg_t)));
    memcpy(&(responsePl->iv), (void*)0xFFE0, 32);
    responsePl->error = SUCCESS;
    call ReadIvResponseSend.send(0, ReadIv_response_msg, sizeof(read_iv_response_msg_t));
  }

  event void ReadIvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadIv_response_msg);
    call Pool.put(ReadIv_cmd_msg);
    ReadIv_cmd_msg = NULL;
    ReadIv_response_msg = NULL;
  }


  //Read bacon Manufacture info
  message_t* ReadMfrId_cmd_msg = NULL;
  message_t* ReadMfrId_response_msg = NULL;
  task void respondReadMfrId();

  event message_t* ReadMfrIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadMfrId_cmd_msg != NULL){
      printf("RX: ReadMfrId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadMfrId_response_msg = call Pool.get();
        ReadMfrId_cmd_msg = msg_;
        post respondReadMfrId();
        return ret;
      }else{
        printf("RX: ReadMfrId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadMfrId(){
//    read_mfr_id_cmd_msg_t* commandPl = (read_mfr_id_cmd_msg_t*)(call Packet.getPayload(ReadMfrId_cmd_msg, sizeof(read_mfr_id_cmd_msg_t)));
    read_mfr_id_response_msg_t* responsePl = (read_mfr_id_response_msg_t*)(call Packet.getPayload(ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t)));
    memcpy(&(responsePl->mfrId), (void*)0x1A0A, 8);
    responsePl->error = SUCCESS;
    call ReadMfrIdResponseSend.send(0, ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t));
  }

  event void ReadMfrIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadMfrId_response_msg);
    call Pool.put(ReadMfrId_cmd_msg);
    ReadMfrId_cmd_msg = NULL;
    ReadMfrId_response_msg = NULL;
  }


//End completed implementations

}
