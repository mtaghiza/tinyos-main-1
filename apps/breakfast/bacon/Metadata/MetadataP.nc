#include "printf.h"
module MetadataP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface Packet;
  uses interface SplitControl as SerialSplitControl;
  uses interface Pool<message_t>;
  
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
uses interface Receive as ResetBusCmdReceive;
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
uses interface AMSend as ResetBusResponseSend;
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

  event void Boot.booted(){
    printf("Booted.\n");
    printfflush();
    call SerialSplitControl.start();
  }

  event void SerialSplitControl.startDone(error_t error){ 
  }

  event void SerialSplitControl.stopDone(error_t error){}

  event void Timer.fired(){ }


//Begin Auto-generated message stubs (see genStubs.sh)
  message_t* ReadIv_cmd_msg = NULL;
  message_t* ReadIv_response_msg = NULL;
  task void respondReadIv();

  event message_t* ReadIvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadIv");
    if (ReadIv_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadIv_response_msg = call Pool.get();
        ReadIv_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadIv();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadIv(){
    read_iv_cmd_msg_t* commandPl = (read_iv_cmd_msg_t*)(call Packet.getPayload(ReadIv_cmd_msg, sizeof(read_iv_cmd_msg_t)));
    read_iv_response_msg_t* responsePl = (read_iv_response_msg_t*)(call Packet.getPayload(ReadIv_response_msg, sizeof(read_iv_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadIvResponseSend.send(0, ReadIv_response_msg, sizeof(read_iv_response_msg_t));
  }

  event void ReadIvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadIv_response_msg);
    call Pool.put(ReadIv_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadMfrId_cmd_msg = NULL;
  message_t* ReadMfrId_response_msg = NULL;
  task void respondReadMfrId();

  event message_t* ReadMfrIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadMfrId");
    if (ReadMfrId_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadMfrId_response_msg = call Pool.get();
        ReadMfrId_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadMfrId();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadMfrId(){
    read_mfr_id_cmd_msg_t* commandPl = (read_mfr_id_cmd_msg_t*)(call Packet.getPayload(ReadMfrId_cmd_msg, sizeof(read_mfr_id_cmd_msg_t)));
    read_mfr_id_response_msg_t* responsePl = (read_mfr_id_response_msg_t*)(call Packet.getPayload(ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadMfrIdResponseSend.send(0, ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t));
  }

  event void ReadMfrIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadMfrId_response_msg);
    call Pool.put(ReadMfrId_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadBaconBarcodeId_cmd_msg = NULL;
  message_t* ReadBaconBarcodeId_response_msg = NULL;
  task void respondReadBaconBarcodeId();

  event message_t* ReadBaconBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadBaconBarcodeId");
    if (ReadBaconBarcodeId_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadBaconBarcodeId_response_msg = call Pool.get();
        ReadBaconBarcodeId_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadBaconBarcodeId();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteBaconBarcodeId_cmd_msg = NULL;
  message_t* WriteBaconBarcodeId_response_msg = NULL;
  task void respondWriteBaconBarcodeId();

  event message_t* WriteBaconBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: WriteBaconBarcodeId");
    if (WriteBaconBarcodeId_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteBaconBarcodeId_response_msg = call Pool.get();
        WriteBaconBarcodeId_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondWriteBaconBarcodeId();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadToastBarcodeId_cmd_msg = NULL;
  message_t* ReadToastBarcodeId_response_msg = NULL;
  task void respondReadToastBarcodeId();

  event message_t* ReadToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadToastBarcodeId");
    if (ReadToastBarcodeId_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadToastBarcodeId_response_msg = call Pool.get();
        ReadToastBarcodeId_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadToastBarcodeId();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastBarcodeId_cmd_msg = NULL;
  message_t* WriteToastBarcodeId_response_msg = NULL;
  task void respondWriteToastBarcodeId();

  event message_t* WriteToastBarcodeIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: WriteToastBarcodeId");
    if (WriteToastBarcodeId_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastBarcodeId_response_msg = call Pool.get();
        WriteToastBarcodeId_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondWriteToastBarcodeId();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadToastAssignments_cmd_msg = NULL;
  message_t* ReadToastAssignments_response_msg = NULL;
  task void respondReadToastAssignments();

  event message_t* ReadToastAssignmentsCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadToastAssignments");
    if (ReadToastAssignments_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadToastAssignments_response_msg = call Pool.get();
        ReadToastAssignments_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadToastAssignments();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastAssignments_cmd_msg = NULL;
  message_t* WriteToastAssignments_response_msg = NULL;
  task void respondWriteToastAssignments();

  event message_t* WriteToastAssignmentsCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: WriteToastAssignments");
    if (WriteToastAssignments_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastAssignments_response_msg = call Pool.get();
        WriteToastAssignments_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondWriteToastAssignments();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* ScanBus_cmd_msg = NULL;
  message_t* ScanBus_response_msg = NULL;
  task void respondScanBus();

  event message_t* ScanBusCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ScanBus");
    if (ScanBus_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ScanBus_response_msg = call Pool.get();
        ScanBus_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondScanBus();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondScanBus(){
    scan_bus_cmd_msg_t* commandPl = (scan_bus_cmd_msg_t*)(call Packet.getPayload(ScanBus_cmd_msg, sizeof(scan_bus_cmd_msg_t)));
    scan_bus_response_msg_t* responsePl = (scan_bus_response_msg_t*)(call Packet.getPayload(ScanBus_response_msg, sizeof(scan_bus_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ScanBusResponseSend.send(0, ScanBus_response_msg, sizeof(scan_bus_response_msg_t));
  }

  event void ScanBusResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ScanBus_response_msg);
    call Pool.put(ScanBus_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* Ping_cmd_msg = NULL;
  message_t* Ping_response_msg = NULL;
  task void respondPing();

  event message_t* PingCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: Ping");
    if (Ping_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        Ping_response_msg = call Pool.get();
        Ping_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondPing();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondPing(){
    ping_cmd_msg_t* commandPl = (ping_cmd_msg_t*)(call Packet.getPayload(Ping_cmd_msg, sizeof(ping_cmd_msg_t)));
    ping_response_msg_t* responsePl = (ping_response_msg_t*)(call Packet.getPayload(Ping_response_msg, sizeof(ping_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call PingResponseSend.send(0, Ping_response_msg, sizeof(ping_response_msg_t));
  }

  event void PingResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(Ping_response_msg);
    call Pool.put(Ping_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* ResetBacon_cmd_msg = NULL;
  message_t* ResetBacon_response_msg = NULL;
  task void respondResetBacon();

  event message_t* ResetBaconCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ResetBacon");
    if (ResetBacon_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ResetBacon_response_msg = call Pool.get();
        ResetBacon_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondResetBacon();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondResetBacon(){
    reset_bacon_cmd_msg_t* commandPl = (reset_bacon_cmd_msg_t*)(call Packet.getPayload(ResetBacon_cmd_msg, sizeof(reset_bacon_cmd_msg_t)));
    reset_bacon_response_msg_t* responsePl = (reset_bacon_response_msg_t*)(call Packet.getPayload(ResetBacon_response_msg, sizeof(reset_bacon_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ResetBaconResponseSend.send(0, ResetBacon_response_msg, sizeof(reset_bacon_response_msg_t));
  }

  event void ResetBaconResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ResetBacon_response_msg);
    call Pool.put(ResetBacon_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* ResetBus_cmd_msg = NULL;
  message_t* ResetBus_response_msg = NULL;
  task void respondResetBus();

  event message_t* ResetBusCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ResetBus");
    if (ResetBus_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ResetBus_response_msg = call Pool.get();
        ResetBus_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondResetBus();
        return ret;
      }else{
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondResetBus(){
    reset_bus_cmd_msg_t* commandPl = (reset_bus_cmd_msg_t*)(call Packet.getPayload(ResetBus_cmd_msg, sizeof(reset_bus_cmd_msg_t)));
    reset_bus_response_msg_t* responsePl = (reset_bus_response_msg_t*)(call Packet.getPayload(ResetBus_response_msg, sizeof(reset_bus_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ResetBusResponseSend.send(0, ResetBus_response_msg, sizeof(reset_bus_response_msg_t));
  }

  event void ResetBusResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ResetBus_response_msg);
    call Pool.put(ResetBus_cmd_msg);
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadBaconTlv_cmd_msg = NULL;
  message_t* ReadBaconTlv_response_msg = NULL;
  task void respondReadBaconTlv();

  event message_t* ReadBaconTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadBaconTlv");
    if (ReadBaconTlv_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadBaconTlv_response_msg = call Pool.get();
        ReadBaconTlv_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadBaconTlv();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* ReadToastTlv_cmd_msg = NULL;
  message_t* ReadToastTlv_response_msg = NULL;
  task void respondReadToastTlv();

  event message_t* ReadToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: ReadToastTlv");
    if (ReadToastTlv_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadToastTlv_response_msg = call Pool.get();
        ReadToastTlv_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondReadToastTlv();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteBaconTlv_cmd_msg = NULL;
  message_t* WriteBaconTlv_response_msg = NULL;
  task void respondWriteBaconTlv();

  event message_t* WriteBaconTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: WriteBaconTlv");
    if (WriteBaconTlv_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteBaconTlv_response_msg = call Pool.get();
        WriteBaconTlv_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondWriteBaconTlv();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* WriteToastTlv_cmd_msg = NULL;
  message_t* WriteToastTlv_response_msg = NULL;
  task void respondWriteToastTlv();

  event message_t* WriteToastTlvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: WriteToastTlv");
    if (WriteToastTlv_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        WriteToastTlv_response_msg = call Pool.get();
        WriteToastTlv_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondWriteToastTlv();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* DeleteBaconTlvEntry_cmd_msg = NULL;
  message_t* DeleteBaconTlvEntry_response_msg = NULL;
  task void respondDeleteBaconTlvEntry();

  event message_t* DeleteBaconTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: DeleteBaconTlvEntry");
    if (DeleteBaconTlvEntry_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        DeleteBaconTlvEntry_response_msg = call Pool.get();
        DeleteBaconTlvEntry_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondDeleteBaconTlvEntry();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* DeleteToastTlvEntry_cmd_msg = NULL;
  message_t* DeleteToastTlvEntry_response_msg = NULL;
  task void respondDeleteToastTlvEntry();

  event message_t* DeleteToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: DeleteToastTlvEntry");
    if (DeleteToastTlvEntry_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        DeleteToastTlvEntry_response_msg = call Pool.get();
        DeleteToastTlvEntry_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondDeleteToastTlvEntry();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* AddBaconTlvEntry_cmd_msg = NULL;
  message_t* AddBaconTlvEntry_response_msg = NULL;
  task void respondAddBaconTlvEntry();

  event message_t* AddBaconTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: AddBaconTlvEntry");
    if (AddBaconTlvEntry_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        AddBaconTlvEntry_response_msg = call Pool.get();
        AddBaconTlvEntry_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondAddBaconTlvEntry();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


  message_t* AddToastTlvEntry_cmd_msg = NULL;
  message_t* AddToastTlvEntry_response_msg = NULL;
  task void respondAddToastTlvEntry();

  event message_t* AddToastTlvEntryCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    printf("RX: AddToastTlvEntry");
    if (AddToastTlvEntry_cmd_msg != NULL){
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        AddToastTlvEntry_response_msg = call Pool.get();
        AddToastTlvEntry_cmd_msg = msg_;
        printf(" OK\n");
        printfflush();
        post respondAddToastTlvEntry();
        return ret;
      }else{
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
    printf("Response sent\n");
    printfflush();
  }


//End auto-generated message stubs
}
