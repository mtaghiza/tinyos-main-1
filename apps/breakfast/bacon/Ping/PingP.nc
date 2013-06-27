module PingP {
  uses interface Get<uint16_t> as RebootCounter;
  uses interface LocalTime<TMilli> as LocalTimeMilli;
  uses interface LocalTime<T32khz> as LocalTime32k;

  uses interface Receive;
  uses interface AMSend;
  uses interface Pool<message_t>;

  uses interface AMPacket;
  uses interface Packet;
} implementation {
  
  message_t* pkt = NULL;
  uint32_t tm;
  uint32_t t32k;

  task void handlePing(){
    ping_msg_t* pingPl = call Packet.getPayload(pkt,
      sizeof(ping_msg_t));
    uint32_t pingId = pingPl->pingId;
    am_addr_t from = call AMPacket.source(pkt);
    pong_msg_t* pongPl;
    call Packet.clear(pkt);
    pongPl->pingId = pingId;
    pongPl->rebootCounter = call RebootCounter.get();
    pongPl->tsMilli = tm;
    pongPl->ts32k   = t32k;
    if (SUCCESS != call AMSend.send(from, pkt, sizeof(pong_msg_t))){
      call Pool.put(pkt);
    }
  }

  event message_t* Receive.receive(message_t* msg, void* pl, uint8_t len){
    if (pkt == NULL){
      return msg;
    }else{
      message_t* ret;
      t32k = call LocalTime32k.get();
      tm = call LocalTimeMilli.get();
      ret = call Pool.get();
      if (ret == NULL){
        return msg;
      }
      pkt = msg;
      post handlePing();
      return ret;
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    if (msg == pkt){
      call Pool.put(pkt);
      pkt = NULL;
    }
  }
}
