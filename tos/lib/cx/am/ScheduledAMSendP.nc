module ScheduledAMSendP {
  provides interface ScheduledAMSend[uint8_t clientId];
  uses interface AMSend as SubAMSend[uint8_t clientId];
  uses interface CXPacketMetadata;
} implementation {
  command error_t ScheduledAMSend.send[uint8_t clientId](am_addr_t addr, 
      message_t* msg, uint8_t len, uint32_t frameNum){
    call CXPacketMetadata.setRequestedFrame(msg, frameNum);
    return call SubAMSend.send[clientId](addr, msg, len);
  }

  command error_t ScheduledAMSend.cancel[uint8_t clientId](message_t* msg){
    return call SubAMSend.cancel[clientId](msg);
  }

  command uint8_t ScheduledAMSend.maxPayloadLength[uint8_t clientId](){
    return call SubAMSend.maxPayloadLength[clientId]();
  }

  command void* ScheduledAMSend.getPayload[uint8_t clientId](message_t* msg, uint8_t len){
    return call SubAMSend.getPayload[clientId](msg, len);
  }

  event void SubAMSend.sendDone[uint8_t clientId](message_t* msg,
      error_t error){
    call CXPacketMetadata.setRequestedFrame(msg, INVALID_FRAME);
    signal ScheduledAMSend.sendDone[clientId](msg, error);
  }

  default event void ScheduledAMSend.sendDone[uint8_t clientId](message_t* msg,
      error_t error){}

}
