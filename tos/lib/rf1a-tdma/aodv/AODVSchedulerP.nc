module AODVSchedulerP{
  provides interface TDMARoutingSchedule[uint8_t rm];

  provides interface Send;
  provides interface Receive;
  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;
} implementation {

  command error_t Send.send(message_t* msg, uint8_t len){
    //TODO: look at address and set up as flood, scoped flood, or
    //pre-routed.
    return FAIL;
  }
  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }
  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  event void ScopedFloodSend.sendDone(message_t* msg, error_t error){
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid.
    return msg;
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid.
    return msg;
  }

  async command bool TDMARoutingSchedule.isForwardOK[uint8_t rm](uint16_t frameNum){
    return TRUE;
  }
  
  //TODO schedule needs to be available here, too. revisit logic for
  //when it gets overridden and when AODV scheduler controls.
  //nuuuuuuuts this layer needs to know about the app-level schedule.
  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
    return FALSE;
  }

  //this should never be called due to the wiring
  async command uint8_t TDMARoutingSchedule.maxRetransmit[uint8_t rm](){
    return 1;
  }
  //this should never be called due to the wiring
  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return 1;
  }
}
