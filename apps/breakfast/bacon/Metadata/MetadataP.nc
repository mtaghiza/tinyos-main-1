
 #include "printf.h"
 #include "GlobalID.h"
 #include "decodeError.h"
 #include "I2CCom.h"
 #include "I2CTLVStorage.h"

module MetadataP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface Packet;
  uses interface SplitControl as SerialSplitControl;
  uses interface Pool<message_t>;

  uses interface I2CDiscoverer;
  uses interface I2CTLVStorageMaster;
  uses interface SplitControl as BusControl;
  uses interface Leds;
  
//Begin Auto-generated used interfaces (see genUsedInterfaces.sh)
//Receive
uses interface Receive as ReadIvCmdReceive;
uses interface Receive as ReadMfrIdCmdReceive;
uses interface Receive as ReadBaconBarcodeIdCmdReceive;
uses interface Receive as WriteBaconBarcodeIdCmdReceive;
uses interface Receive as ReadToastBarcodeIdCmdReceive;
uses interface Receive as WriteToastBarcodeIdCmdReceive;
uses interface Receive as ReadToastAssignmentsCmdReceive;
uses interface Receive as WriteToastAssignmentsCmdReceive;
uses interface Receive as ScanBusCmdReceive;
uses interface Receive as PingCmdReceive;
uses interface Receive as ResetBaconCmdReceive;
uses interface Receive as SetBusPowerCmdReceive;
uses interface Receive as ReadBaconTlvCmdReceive;
uses interface Receive as ReadToastTlvCmdReceive;
uses interface Receive as WriteBaconTlvCmdReceive;
uses interface Receive as WriteToastTlvCmdReceive;
uses interface Receive as DeleteBaconTlvEntryCmdReceive;
uses interface Receive as DeleteToastTlvEntryCmdReceive;
uses interface Receive as AddBaconTlvEntryCmdReceive;
uses interface Receive as AddToastTlvEntryCmdReceive;
//Send
uses interface AMSend as ReadIvResponseSend;
uses interface AMSend as ReadMfrIdResponseSend;
uses interface AMSend as ReadBaconBarcodeIdResponseSend;
uses interface AMSend as WriteBaconBarcodeIdResponseSend;
uses interface AMSend as ReadToastBarcodeIdResponseSend;
uses interface AMSend as WriteToastBarcodeIdResponseSend;
uses interface AMSend as ReadToastAssignmentsResponseSend;
uses interface AMSend as WriteToastAssignmentsResponseSend;
uses interface AMSend as ScanBusResponseSend;
uses interface AMSend as PingResponseSend;
uses interface AMSend as ResetBaconResponseSend;
uses interface AMSend as SetBusPowerResponseSend;
uses interface AMSend as ReadBaconTlvResponseSend;
uses interface AMSend as ReadToastTlvResponseSend;
uses interface AMSend as WriteBaconTlvResponseSend;
uses interface AMSend as WriteToastTlvResponseSend;
uses interface AMSend as DeleteBaconTlvEntryResponseSend;
uses interface AMSend as DeleteToastTlvEntryResponseSend;
uses interface AMSend as AddBaconTlvEntryResponseSend;
uses interface AMSend as AddToastTlvEntryResponseSend;
//End Auto-generated used interfaces
  
} implementation {
  enum {
    S_BOOTING ,
    S_READY
  };

  uint8_t state = S_BOOTING;
  uint8_t slaveCount;
  uint8_t lastSlave;
  error_t scanBus_err;
  error_t setBusPower_error;
  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;

  event void Boot.booted(){
    call Leds.led0On();
    printf("Booted.\n");
    printfflush();
    call SerialSplitControl.start();
  }
  
  task void respondResetBacon();
  task void respondSetBusPower();

  event void SerialSplitControl.startDone(error_t error){ 
    state = S_READY;
    post respondResetBacon();
  }

  event void BusControl.startDone(error_t error){
    setBusPower_error = error;
    post respondSetBusPower();
  }

  event void BusControl.stopDone(error_t error){
    setBusPower_error = error;
    post respondSetBusPower();
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return TOS_NODE_ID & 0x7F;
  }

  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery){
    uint8_t i;
    slaveCount++;
    printf("Assigned %x to ", discovery->val.localAddr);
    for ( i = 0 ; i < GLOBAL_ID_LEN; i++){
      printf("%x ", discovery->val.globalAddr[i]);
    }
    if (slaveCount == 1){
      lastSlave = discovery->val.localAddr;
    }else{
      lastSlave = 0;
    }
    printf("\n");
    printfflush();
    return discovery;
  }

  task void respondScanBus();
  event void I2CDiscoverer.discoveryDone(error_t error){
    scanBus_err = error;
    post respondScanBus();
  }



  event void SerialSplitControl.stopDone(error_t error){}

  event void Timer.fired(){ }

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
    read_bacon_barcode_id_cmd_msg_t* commandPl = (read_bacon_barcode_id_cmd_msg_t*)(call Packet.getPayload(ReadBaconBarcodeId_cmd_msg, sizeof(read_bacon_barcode_id_cmd_msg_t)));
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
    write_bacon_barcode_id_cmd_msg_t* commandPl = (write_bacon_barcode_id_cmd_msg_t*)(call Packet.getPayload(WriteBaconBarcodeId_cmd_msg, sizeof(write_bacon_barcode_id_cmd_msg_t)));
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
    read_toast_barcode_id_cmd_msg_t* commandPl = (read_toast_barcode_id_cmd_msg_t*)(call Packet.getPayload(ReadToastBarcodeId_cmd_msg, sizeof(read_toast_barcode_id_cmd_msg_t)));
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
    write_toast_barcode_id_cmd_msg_t* commandPl = (write_toast_barcode_id_cmd_msg_t*)(call Packet.getPayload(WriteToastBarcodeId_cmd_msg, sizeof(write_toast_barcode_id_cmd_msg_t)));
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
    read_toast_assignments_cmd_msg_t* commandPl = (read_toast_assignments_cmd_msg_t*)(call Packet.getPayload(ReadToastAssignments_cmd_msg, sizeof(read_toast_assignments_cmd_msg_t)));
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
    write_toast_assignments_cmd_msg_t* commandPl = (write_toast_assignments_cmd_msg_t*)(call Packet.getPayload(WriteToastAssignments_cmd_msg, sizeof(write_toast_assignments_cmd_msg_t)));
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
    read_bacon_tlv_cmd_msg_t* commandPl = (read_bacon_tlv_cmd_msg_t*)(call Packet.getPayload(ReadBaconTlv_cmd_msg, sizeof(read_bacon_tlv_cmd_msg_t)));
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


  message_t* ReadToastTlv_cmd_msg = NULL;
  message_t* ReadToastTlv_response_msg = NULL;
  error_t readToastTLVError = FAIL;

  task void respondReadToastTlv();
  task void reportReadToastTLVError();

  task void loadToastTLVStorage(){
    readToastTLVError = call I2CTLVStorageMaster.loadTLVStorage(lastSlave,
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
        if (lastSlave ==0){
          readToastTLVError = EOFF;
          post reportReadToastTLVError();
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
    read_toast_tlv_cmd_msg_t* commandPl = (read_toast_tlv_cmd_msg_t*)(call Packet.getPayload(ReadToastTlv_cmd_msg, sizeof(read_toast_tlv_cmd_msg_t)));
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
    write_bacon_tlv_cmd_msg_t* commandPl = (write_bacon_tlv_cmd_msg_t*)(call Packet.getPayload(WriteBaconTlv_cmd_msg, sizeof(write_bacon_tlv_cmd_msg_t)));
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
    write_toast_tlv_cmd_msg_t* commandPl = (write_toast_tlv_cmd_msg_t*)(call Packet.getPayload(WriteToastTlv_cmd_msg, sizeof(write_toast_tlv_cmd_msg_t)));
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
    delete_bacon_tlv_entry_cmd_msg_t* commandPl = (delete_bacon_tlv_entry_cmd_msg_t*)(call Packet.getPayload(DeleteBaconTlvEntry_cmd_msg, sizeof(delete_bacon_tlv_entry_cmd_msg_t)));
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
    delete_toast_tlv_entry_cmd_msg_t* commandPl = (delete_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(DeleteToastTlvEntry_cmd_msg, sizeof(delete_toast_tlv_entry_cmd_msg_t)));
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
    add_bacon_tlv_entry_cmd_msg_t* commandPl = (add_bacon_tlv_entry_cmd_msg_t*)(call Packet.getPayload(AddBaconTlvEntry_cmd_msg, sizeof(add_bacon_tlv_entry_cmd_msg_t)));
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
    add_toast_tlv_entry_cmd_msg_t* commandPl = (add_toast_tlv_entry_cmd_msg_t*)(call Packet.getPayload(AddToastTlvEntry_cmd_msg, sizeof(add_toast_tlv_entry_cmd_msg_t)));
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
  
  //Ping
  message_t* Ping_cmd_msg = NULL;
  message_t* Ping_response_msg = NULL;
  task void respondPing();

  event message_t* PingCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (Ping_cmd_msg != NULL){
      printf("RX: Ping");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        Ping_response_msg = call Pool.get();
        Ping_cmd_msg = msg_;
        post respondPing();
        return ret;
      }else{
        printf("RX: Ping");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondPing(){
    ping_response_msg_t* responsePl = (ping_response_msg_t*)(call Packet.getPayload(Ping_response_msg, sizeof(ping_response_msg_t)));
    responsePl->error = SUCCESS;
    call PingResponseSend.send(0, Ping_response_msg, sizeof(ping_response_msg_t));
  }

  event void PingResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(Ping_response_msg);
    call Pool.put(Ping_cmd_msg);
    Ping_cmd_msg = NULL;
    Ping_response_msg = NULL;
  }

  //Scan bus
  message_t* ScanBus_cmd_msg = NULL;
  message_t* ScanBus_response_msg = NULL;
  task void respondScanBus();
  task void startDiscovery();

  event message_t* ScanBusCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ScanBus_cmd_msg != NULL){
      printf("RX: ScanBus");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ScanBus_response_msg = call Pool.get();
        ScanBus_cmd_msg = msg_;
        post startDiscovery();
        return ret;
      }else{
        printf("RX: ScanBus");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void startDiscovery(){
    slaveCount = 0;
    call I2CDiscoverer.startDiscovery(TRUE, 0x40);
  }


  task void respondScanBus(){
    scan_bus_cmd_msg_t* commandPl = (scan_bus_cmd_msg_t*)(call Packet.getPayload(ScanBus_cmd_msg, sizeof(scan_bus_cmd_msg_t)));
    scan_bus_response_msg_t* responsePl = (scan_bus_response_msg_t*)(call Packet.getPayload(ScanBus_response_msg, sizeof(scan_bus_response_msg_t)));
    responsePl->error = scanBus_err;
    responsePl->numFound = slaveCount;
    call ScanBusResponseSend.send(0, ScanBus_response_msg, sizeof(scan_bus_response_msg_t));
  }

  event void ScanBusResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ScanBus_response_msg);
    call Pool.put(ScanBus_cmd_msg);
    ScanBus_cmd_msg = NULL;
    ScanBus_response_msg = NULL;
    printf("Response sent\n");
    printfflush();
  }


  message_t* SetBusPower_cmd_msg = NULL;
  message_t* SetBusPower_response_msg = NULL;

  task void reportBusPowerError(){
    set_bus_power_response_msg_t* responsePl = (set_bus_power_response_msg_t*)(call Packet.getPayload(SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t)));
    responsePl->error = setBusPower_error;
    call SetBusPowerResponseSend.send(0, SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t));
  }

  task void setPowerTask(){
    set_bus_power_cmd_msg_t* commandPl = (set_bus_power_cmd_msg_t*)(call Packet.getPayload(SetBusPower_cmd_msg, sizeof(set_bus_power_cmd_msg_t)));
    if (commandPl->powerOn){
      setBusPower_error = call BusControl.start();
    } else {
      setBusPower_error = call BusControl.stop();
    }
    if (setBusPower_error != SUCCESS){
      post reportBusPowerError();
    }
  }

  event message_t* SetBusPowerCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (SetBusPower_cmd_msg != NULL){
      printf("RX: SetBusPower");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        SetBusPower_response_msg = call Pool.get();
        SetBusPower_cmd_msg = msg_;
        post setPowerTask();
        return ret;
      }else{
        printf("RX: SetBusPower");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondSetBusPower(){
    set_bus_power_cmd_msg_t* commandPl = (set_bus_power_cmd_msg_t*)(call Packet.getPayload(SetBusPower_cmd_msg, sizeof(set_bus_power_cmd_msg_t)));
    set_bus_power_response_msg_t* responsePl = (set_bus_power_response_msg_t*)(call Packet.getPayload(SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t)));
    responsePl->error = SUCCESS;
    call SetBusPowerResponseSend.send(0, SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t));
  }

  event void SetBusPowerResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(SetBusPower_response_msg);
    call Pool.put(SetBusPower_cmd_msg);
    SetBusPower_cmd_msg = NULL;
    SetBusPower_response_msg = NULL;
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
    read_iv_cmd_msg_t* commandPl = (read_iv_cmd_msg_t*)(call Packet.getPayload(ReadIv_cmd_msg, sizeof(read_iv_cmd_msg_t)));
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
    read_mfr_id_cmd_msg_t* commandPl = (read_mfr_id_cmd_msg_t*)(call Packet.getPayload(ReadMfrId_cmd_msg, sizeof(read_mfr_id_cmd_msg_t)));
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
