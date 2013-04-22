module ScheduledTXP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface Packet;
  uses interface SplitControl;
  uses interface CXPacketMetadata;
  uses interface AMPacket;
} implementation {

  command error_t Send.send(message_t* msg, uint8_t len){
    //broadcast only!
    if (call AMPacket.destination(msg) != AM_BROADCAST_ADDR){
      return EINVAL;
    }

    return call CXRequestQueue.requestSend(0,
      call CXPacketMetadata.getRequestedFrame(msg), 0,
      FALSE, 0,
      NULL, //TODO: need to stash ts location in md, too
      NULL, msg);
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  event void SplitControl.startDone(error_t error){}
  event void SplitControl.stopDone(error_t error){}
  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){}

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal Send.sendDone(msg, error);
  }

  event void CXRequestQueue.sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){
  }
}
