module SimpleFloodSchedulerP{
  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface AMPacket;
  uses interface CXPacket;

  uses interface Packet as AMPacketBody;
  uses interface FrameStarted;

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
  uint16_t lastSent;
  message_t* outstandingMsg;
  error_t sdError;

  task void signalDone();

  command error_t AMSend.send[am_id_t id](am_addr_t addr, 
      message_t* msg, uint8_t len){
    if (state == S_IDLE){
      error_t error ;
      call AMPacketBody.setPayloadLength(msg, len);
      call AMPacket.setType(msg, id);
      call CXPacket.setDestination(msg, addr);
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
    //Upon completion at network layer, read original frame num from
    //cx header
    if (state == S_SENDING){
      state = S_CLEARING;
      outstandingMsg = msg;
      sdError = error;
      lastSent = call CXPacket.getOriginalFrameNum(msg);
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    //TODO: FLOOD_CLEAR_TIME = maxDepth + retransmits
    if (state == S_CLEARING && frameNum > (lastSent + SCHED_MAX_DEPTH + SCHED_MAX_RETRANSMIT)){
      post signalDone();
    }
  }

  async command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched(frameNum) && state == S_PENDING){
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

  task void signalDone(){
    state = S_IDLE;
    signal AMSend.sendDone[call AMPacket.type(outstandingMsg)](outstandingMsg, sdError);
  }

  command error_t AMSend.cancel[am_id_t id](message_t* msg){
    return FAIL;
  }

  command uint8_t AMSend.maxPayloadLength[am_id_t id](){
    return call AMPacketBody.maxPayloadLength();
  }

  command void* AMSend.getPayload[am_id_t id](message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: might be necessary to restore AMPacket's destination field
    //(from CXPacket header)?
    return signal Receive.receive[call AMPacket.type(msg)](msg,
      call AMPacketBody.getPayload(msg, 
        call AMPacketBody.payloadLength(msg)),
      call AMPacketBody.payloadLength(msg));
  }

  default event void AMSend.sendDone[am_id_t id](message_t* msg, error_t error){ }
  default event message_t* Receive.receive[am_id_t id](message_t* msg, 
      void* payload, uint8_t len){ 
    return msg;
  }
}
