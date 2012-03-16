 #include "CX.h"

module Rf1aCXPacketP{
  provides interface CXPacket;
  provides interface Packet;
  uses interface AMPacket as AMPacket;
  uses interface Packet as SubPacket;
  uses interface Rf1aPacket; 
  uses interface Ieee154Packet;
  uses interface ActiveMessageAddress;
} implementation {
  //this should probably be longer, right?
  uint8_t cxSN = 0;

  cx_header_t* getHeader(message_t* msg){
    return (cx_header_t*)(call SubPacket.getPayload(msg, sizeof(cx_header_t)));
  }

  command void CXPacket.init(message_t* msg){
    call Rf1aPacket.configureAsData(msg);
    call AMPacket.setSource(msg, call AMPacket.address());
    call Ieee154Packet.setPan(msg, call Ieee154Packet.localPan());
    call CXPacket.setCount(msg, 0);
    call CXPacket.newSn(msg);
  }

  command void Packet.clear(message_t* msg) {
    call SubPacket.clear(msg);
    //TODO: reset anything germane to this header
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) - sizeof(cx_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len){
    //TODO: double-check: shouldn't need to do anything here.
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    if (len <= call Packet.maxPayloadLength()){
      return (void*) (sizeof(cx_header_t) + (call SubPacket.getPayload(msg,
        len+sizeof(cx_header_t))));
    } else {
      return 0;
    }
  }

  command am_addr_t CXPacket.destination(message_t* amsg){
    return getHeader(amsg)->destination;
  }

  command void CXPacket.setDestination(message_t* amsg, am_addr_t addr){
    getHeader(amsg)->destination = addr;
  }

  command am_addr_t CXPacket.source(message_t* amsg){
    return call Ieee154Packet.source(amsg);
  }
  command void CXPacket.setSource(message_t* amsg, am_addr_t addr){
    call Ieee154Packet.setSource(amsg, addr);
  }

  //argh why doesn't ieee154packet expose this?
  command uint8_t CXPacket.sn(message_t* amsg){
    return getHeader(amsg)->sn;
  }

  async command void CXPacket.newSn(message_t* amsg){
    atomic{
      getHeader(amsg)->sn = cxSN ++;
    }
  }

  command uint8_t CXPacket.count(message_t* amsg){
    return getHeader(amsg)->count;
  }

  command void CXPacket.setCount(message_t* amsg, uint8_t cxcount){
    getHeader(amsg)->count = cxcount;
  }
  command void CXPacket.incCount(message_t* amsg){
    getHeader(amsg)->count++;
  }


  command bool CXPacket.isForMe(message_t* amsg){
    return (call CXPacket.destination(amsg) == call
    ActiveMessageAddress.amAddress() ||
            call CXPacket.destination(amsg) == AM_BROADCAST_ADDR);
  }

  command am_id_t CXPacket.type(message_t* amsg){
    return getHeader(amsg)->type;
  }
  command void CXPacket.setType(message_t* amsg, am_id_t t){
    getHeader(amsg)->type = t;
  }

  command uint8_t CXPacket.getRoutingMethod(message_t* amsg){
    return getHeader(amsg)->routingMethod;
  }
  command void CXPacket.setRoutingMethod(message_t* amsg,
      uint8_t t){
    getHeader(amsg)->routingMethod = t;
  }

  command uint32_t CXPacket.getTimestamp(message_t* amsg){
    return getHeader(amsg)->timestamp;
  }
  command void CXPacket.setTimestamp(message_t* amsg,
      uint32_t ts){
    getHeader(amsg)->timestamp = ts;
  }



  async event void ActiveMessageAddress.changed(){ }
}
