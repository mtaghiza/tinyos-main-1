module RRBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  //for setup/ack packets
  uses interface Packet;
} implementation {

  command error_t Send.send(message_t* msg, uint8_t len){
    return FAIL;
  }

  command error_t Send.cancel(message_t* msg){
    //not supported
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: received + data ? signal Receive.received with the relevant
    //  details, request next RX
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: signal SendDone if this was data, otherwise update state
    //for setup process
  }

  //unused events below
  event void CXRequestQueue.sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.frameShiftHandled(error_t error,
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
}
