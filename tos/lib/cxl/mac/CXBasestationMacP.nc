module CXBasestationMacP{
  provides interface CXMacController;
  provides interface CXMacMaster;
  provides interface Send;
  uses interface Send as SubSend;
  uses interface Pool<message_t>;

  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;

}implementation {

  message_t* cts;
  bool grantPending = FALSE;
  //Base station is always allowed to send, so just grant the request.
  task void signalGranted(){
    grantPending = FALSE;
    signal CXMacController.requestGranted();
  }

  command error_t CXMacController.requestSend(message_t* msg){
    if (cts != NULL && msg != cts){
      grantPending = TRUE;
      return SUCCESS;
    }else{
      post signalGranted();
    }
    return SUCCESS;
  }
  
  command error_t Send.send(message_t* msg, uint8_t len){
    call CXMacPacket.setMacType(msg, CXM_DATA);
    return call SubSend.send(msg, len);
  }

  command error_t CXMacMaster.cts(am_addr_t node){
    if (cts != NULL){
      return ERETRY;
    } else {
      cts = call Pool.get();
      if (cts){
        error_t error;
        call Packet.clear(cts);
        call CXMacPacket.setMacType(cts, CXM_CTS);
        (call CXLinkPacket.getLinkHeader(cts))->destination = node;
        error = call SubSend.send(cts, 0);
        if (SUCCESS != error){
          call Pool.put(cts);
          cts = NULL;
        }
        return error;
      } else {
        return ENOMEM;
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    printf("bsm.sd\r\n");
    if (cts && cts == msg){
      call Pool.put(cts);
      cts = NULL;
      if (grantPending){
        post signalGranted();
      }
      signal CXMacMaster.ctsDone(
        (call CXLinkPacket.getLinkHeader(msg))->destination,
        error);
    }else {
      signal Send.sendDone(msg, error);
    }
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call SubSend.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call SubSend.maxPayloadLength();
  }
  command error_t Send.cancel(message_t* msg){
    return call SubSend.cancel(msg);
  }
}
