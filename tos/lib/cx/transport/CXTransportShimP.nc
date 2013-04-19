module CXTransportShimP {
  provides interface Send;
  provides interface Receive;
  uses interface Send as BroadcastSend;
  uses interface Receive as BroadcastReceive;
  uses interface Send as UnicastSend;
  uses interface Receive as UnicastReceive;

  uses interface Packet;
  uses interface AMPacket;
} implementation {
  
  command error_t Send.send(message_t* msg, uint8_t len){
    call Packet.setPayloadLength(msg, len);
    if (call AMPacket.destination(msg) == AM_BROADCAST_ADDR){
      return call BroadcastSend.send(msg, len);
    } else {
      return call UnicastSend.send(msg, len);
    }
  }

  command error_t Send.cancel(message_t* msg){
    //TODO: not supported
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
