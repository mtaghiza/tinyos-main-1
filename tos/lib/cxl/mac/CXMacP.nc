
 #include "CXMac.h"
module CXMacP{
  provides interface Send;
  uses interface Send as SubSend;
  uses interface CXMacController;
  uses interface Timer<TMilli>;
} implementation {
  
  message_t* pendingMsg = NULL;
  bool sendStarted = FALSE;
  uint8_t pendingLen;
  uint8_t retryCount;

  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg){
      return EBUSY;
    }else{
      error_t e = call CXMacController.requestSend(msg);
      if (e == SUCCESS){
        retryCount = 0;
        pendingMsg = msg;
        pendingLen = len;
      }
      return e;
    }
  }

  event void Timer.fired(){
    signal CXMacController.requestGranted();
  }

  event void CXMacController.requestGranted(){
    if (pendingMsg){
      error_t error = call SubSend.send(pendingMsg, pendingLen);
      if (error == ERETRY || error == EBUSY){
        retryCount ++;
        if (retryCount <= MAC_RETRY_LIMIT){
          call Timer.startOneShot(128UL);
          return;
        }
      }
      if (error != SUCCESS){
        message_t* msg = pendingMsg;
        pendingMsg = NULL;
        signal Send.sendDone(msg, error);
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
