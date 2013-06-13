module CXMacP{
  provides interface Send;
  uses interface CXMacController;
} implementation {
  
  message_t* pendingMsg = NULL;
  uint8_t pendingLen;
  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg){
      return EBUSY;
    }else{
      error_t e = call CXMacController.requestSend();
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
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    pendingMsg = NULL;
    signal Send.sendDone(msg, error);
  }

}
