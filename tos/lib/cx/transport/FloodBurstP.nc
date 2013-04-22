module FloodBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface Packet;
  uses interface SplitControl;
} implementation {
  message_t msg_internal;
  //We only own this buffer when there is no rx pending. We have no
  //guarantee that we'll get the same buffer back when the receive is
  //handled.
  message_t* rxMsg = &msg_internal;
  bool sending = FALSE;
  bool rxPending = FALSE;
  bool on = FALSE;

  task void receiveNext(){
    if ( on && !rxPending){
      uint32_t nf = call CXRequestQueue.nextFrame(FALSE);
      error_t error = call CXRequestQueue.requestReceive(0,
        nf, 0,
        FALSE, 0,
        0, NULL, rxMsg);
      if (error != SUCCESS){
        printf("!fb.rn: %x\r\n", error);
      }else{
        rxPending = TRUE;
      }
    }
  }

  event void SplitControl.startDone(error_t error){
    if (error == SUCCESS){
      on = TRUE;
      post receiveNext();
    } else {
      printf("!fb.sc.startDone: %x\r\n", error);
    }
  }

  event void SplitControl.stopDone(error_t error){
    if (SUCCESS == error){
      on = FALSE;
    }
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (! sending){
      uint32_t nf = call CXRequestQueue.nextFrame(TRUE);
      if (nf != INVALID_FRAME){
        error_t error = call CXRequestQueue.requestSend(0,
          nf, 0,
          FALSE, 0,
          NULL, NULL,
          msg);
        if (error == SUCCESS){
          sending = TRUE;
        }
        return error;
      }else{
        return FAIL;
      }
    } else { 
      return ERETRY;
    }
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
    if (rxPending){
      rxMsg = msg;
      rxPending = FALSE;
      if (didReceive){
        uint8_t pll = call Packet.payloadLength(msg);
        rxMsg = signal Receive.receive(msg, 
          call Packet.getPayload(msg, pll),
          pll);
      }
      post receiveNext();
    } else {
      printf("!fb.rh, not rxPending\r\n");
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    sending = FALSE;
    signal Send.sendDone(msg, error);
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
}
