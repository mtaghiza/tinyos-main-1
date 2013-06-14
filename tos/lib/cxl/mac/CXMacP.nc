module CXMacP{
  provides interface Send;
  uses interface Send as SubSend;
  uses interface CXMacController;
} implementation {
  
  message_t* pendingMsg = NULL;
  bool sendStarted = FALSE;
  uint8_t pendingLen;
  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg){
      return EBUSY;
    }else{
      error_t e = call CXMacController.requestSend(msg);
      if (e == SUCCESS){
        pendingMsg = msg;
        pendingLen = len;
      }
      return SUCCESS;
    }
  }

  event void CXMacController.requestGranted(){
    if (pendingMsg){
      error_t error = call SubSend.send(pendingMsg, pendingLen);
      if (error != SUCCESS){
        signal Send.sendDone(pendingMsg, error);
      }else{
        sendStarted = TRUE;
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    sendStarted = FALSE;
    pendingMsg = NULL;
    signal Send.sendDone(msg, error);
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call SubSend.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call SubSend.maxPayloadLength();
  }
  command error_t Send.cancel(message_t* msg){
    if (msg == pendingMsg){
      if (!sendStarted){
        pendingMsg = NULL;
        return SUCCESS;
      } else {
        error_t error = call SubSend.cancel(msg);
        if (error == SUCCESS){
          pendingMsg = NULL;
          sendStarted = FALSE;
        }
        return error;
      }
    } else {
      return FAIL;
    }
  }

}
