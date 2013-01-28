module UtilitiesP{
  uses interface Receive as PingCmdReceive;
  uses interface AMSend as PingResponseSend;
  uses interface Packet;
  uses interface AMPacket;
  uses interface Pool<message_t>;
} implementation {
 
  am_addr_t cmdSource;

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
        cmdSource = call AMPacket.source(msg_);
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
    call PingResponseSend.send(cmdSource, Ping_response_msg, sizeof(ping_response_msg_t));
  }

  event void PingResponseSend.sendDone(message_t* msg, 
      error_t error){
    printfflush();
    call Pool.put(Ping_response_msg);
    call Pool.put(Ping_cmd_msg);
    Ping_cmd_msg = NULL;
    Ping_response_msg = NULL;
  }

}
