module CXTransportShimP {
  provides interface Send;
  provides interface Receive;
  uses interface Send as BroadcastSend;
  uses interface Receive as BroadcastReceive;
  uses interface Send as UnicastSend;
  uses interface Receive as UnicastReceive;
} implementation {
  
  command error_t Send.send(message_t* msg, uint8_t len){
    //TODO: check address, call relevant sub-send
    return FAIL;
  }

  command error_t Send.cancel(message_t* msg){
    //TODO: check address, call relevant sub-send
    return FAIL;
  }
  command uint8_t Send.maxPayloadLength(){
    return call BroadcastSend.maxPayloadLength();
  }
  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call BroadcastSend.getPayload(msg, len);
  }

  event void BroadcastSend.sendDone(message_t* msg, error_t error){
    signal Send.sendDone(msg, error);
  }
  event void UnicastSend.sendDone(message_t* msg, error_t error){
    signal Send.sendDone(msg, error);
  }
  
  event message_t* UnicastReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return signal Receive.receive(msg, payload, len);
  }
  event message_t* BroadcastReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return signal Receive.receive(msg, payload, len);
  }
}
