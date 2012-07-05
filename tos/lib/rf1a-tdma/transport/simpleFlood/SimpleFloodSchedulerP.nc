module SimpleFloodSchedulerP{
  provides interface Send;
  provides interface Receive;

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Packet as AMPacketBody;

  uses interface TDMARoutingSchedule;

  provides interface CXTransportSchedule;
} implementation {
  enum {
    S_IDLE,
    S_PENDING,
    S_SENDING,
    S_CLEARING,
  };

  uint8_t state = S_IDLE;

  command error_t Send.send(message_t* msg, uint8_t len){
    if (state == S_IDLE){
      error_t error ;
      call CXPacketMetadata.setRequiresClear(msg, TRUE);
      error = call FloodSend.send(msg, len);
      if (error == SUCCESS){
        state = S_PENDING;
      }
      return error;
    }else{
      return EBUSY;
    }
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
    state = S_IDLE;
    signal Send.sendDone(msg, error);
  }

  command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched() && state == S_PENDING){
      if(call TDMARoutingSchedule.ownsFrame(frameNum)){
        state = S_SENDING;
        return TRUE;
      }else{
        return FALSE;
      }
    }else{
      return FALSE;
    }
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call AMPacketBody.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: might be necessary to restore AMPacket's destination field
    //(from CXPacket header)?
    return signal Receive.receive(msg,
      call AMPacketBody.getPayload(msg, 
        call AMPacketBody.payloadLength(msg)),
      call AMPacketBody.payloadLength(msg));
  }

}
