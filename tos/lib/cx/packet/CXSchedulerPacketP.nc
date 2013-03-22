module CXSchedulerPacketP {
  provides interface Packet;
  provides interface CXSchedulerPacket;

  uses interface Packet as SubPacket;
} implementation {
  cx_schedule_header_t* getHeader(message_t* msg){
    return call SubPacket.getPayload(msg,
      sizeof(cx_schedule_header_t));
  }

  command void Packet.clear(message_t* msg){
      call SubPacket.clear(msg);
    getHeader(msg) -> sn = INVALID_SCHEDULE;
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_schedule_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_schedule_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() -
      sizeof(cx_schedule_header_t);
  }

  command void* Packet.getPayload(message_t* msg, 
      uint8_t len){
    void* pl = call SubPacket.getPayload(msg,
      len + sizeof(cx_schedule_header_t));
    if (pl){
      return pl + sizeof(cx_schedule_header_t);
    }else{
      return pl;
    }
  }

  command uint8_t CXSchedulerPacket.getScheduleNumber(message_t* msg){
    return getHeader(msg)->sn;
  }

  command void CXSchedulerPacket.setOriginFrame(message_t* msg,
      uint32_t originFrame){
    getHeader(msg)->originFrame = originFrame;
  }

  command uint32_t CXSchedulerPacket.getOriginFrame(message_t* msg){
    return getHeader(msg)->originFrame;
  }

  command void CXSchedulerPacket.setScheduleNumber(message_t* msg,
      uint8_t sn){
    getHeader(msg)->sn = sn;
  }

}
