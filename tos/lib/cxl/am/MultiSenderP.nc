generic module MultiSenderP(){
  provides interface AMSend[am_id_t];
  uses interface Send;
  uses interface AMPacket;
} implementation {
  command error_t AMSend.send[am_id_t id](am_addr_t addr, 
      message_t* msg, uint8_t len){
    call AMPacket.setType(msg, id);
    call AMPacket.setDestination(msg, addr);
    return call Send.send(msg, len);
  }
  command void* AMSend.getPayload[am_id_t id](message_t* msg, uint8_t len){
    return call Send.getPayload(msg, len);
  }
  command uint8_t AMSend.maxPayloadLength[am_id_t id](){
    return call Send.maxPayloadLength();
  }
  command error_t AMSend.cancel[am_id_t id](message_t* msg){
    return call Send.cancel(msg);
  }
  event void Send.sendDone(message_t* msg, error_t error){
    signal AMSend.sendDone[call AMPacket.type(msg)](msg, error);
  } 
}
