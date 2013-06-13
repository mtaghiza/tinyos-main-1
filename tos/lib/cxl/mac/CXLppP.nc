module CXLppP {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  uses interface SplitControl as SubSplitControl;
  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface Pool<message_t>;

  uses interface CXLink;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;
  //This packet interface goes to body of mac packet
  uses interface Packet;
} implementation {

  command error_t LppControl.wakeup(){
    return FAIL;
  }
  command error_t LppControl.sleep(){
    return FAIL;
  }
  command error_t LppControl.setProbeInterval(uint32_t t){
    return FAIL;
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    //TODO: set TTL
    return FAIL;
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    //TODO: this layer? stop it here. otherwise, signal it up.
  }
  
  event void CXLink.rxDone(){
  }
  
  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    //TODO: this layer? stop it here. otherwise, signal it up.
    //TODO: adjust payload/len refs
    return signal Receive.receive(msg, pl, len);
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command error_t Send.cancel(message_t* msg){
    return call SubSend.cancel(msg);
  }
  

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  event void CXLink.toneSent(){}
  event void CXLink.toneReceived(bool received){}
}
