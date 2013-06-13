module CXLeafMacP {
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;
  //TODO: hook up relevant *packet interfaces
} implementation {
  bool requestPending = FALSE;

  task void signalGranted(){
    requestPending = FALSE;
    signal CXMacController.requestGranted();
  }

  event message_t* SubReceive.receive(message_t* msg, 
      void* pl, uint8_t len){
    //TODO: fix TOS_NODE_ID ref
    if (call CXMacPacket.getMacType(msg) == CXM_CTS 
        && call CXLinkPacket.destination(msg) == TOS_NODE_ID 
        && requestPending){
      post signalGranted();
    }
    return msg;
  }

  command error_t CXMacController.requestSend(){
    if (requestPending){
      return EBUSY;
    }else{
      requestPending = TRUE;
      return SUCCESS;
    }
  }
  
}
