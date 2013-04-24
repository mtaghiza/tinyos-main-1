module RRBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface SplitControl;
  //for setup/ack packets
  uses interface Packet;
} implementation {

  command error_t Send.send(message_t* msg, uint8_t len){
    //TODO: set up packet
    // - lastTX >= lss? check for whether there's time to finish the
    //   transmission
    //   - TTL = d_sd
    // - no: put SETUP in header
    //   - put in d_ds if available
    //   - enqueue at nss
    //   - TTL = max
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
    //TODO: received + SETUP
    // - If destination, put together an ACK packet
    //   - header: ACK, d_sd
    //   - request send at next frame
    // - If ! destination and d_ds is available, check d_ds and d_si and
    //   sleep if !between
    //TODO: waiting, !received, atFrame >= setupDoneFrame + max
    //   distance: signal sendDone with ENOACK.
    //TODO: waiting, received + ACK: we are now good to start sending.
    //   Signal sendDone SUCCESS with SETUP packet.
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: signal SendDone if this was data, otherwise update state
    //for setup process
    //TODO: this was SETUP: I am now waiting for receiveHandled +
    //  didReceive. Set the timeout frame for this response (default
    //  distance + atFrame). Wait to signal sendDone
    //TODO: this was data: signal sendDone(SUCCESS)
  }

  event void SplitControl.startDone(error_t error){ }
  event void SplitControl.stopDone(error_t error){ }

  //unused events below
  event void CXRequestQueue.sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){
  }
}
