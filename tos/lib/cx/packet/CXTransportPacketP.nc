
 #include "CXTransport.h"
module CXTransportPacketP{
  provides interface Packet;
  uses interface Packet as SubPacket;
  provides interface CXTransportPacket;
} implementation {
  cx_transport_header_t* getHeader(message_t* msg){
    return call SubPacket.getPayload(msg,
      sizeof(cx_transport_header_t));
  }

  command void Packet.clear(message_t* msg){
      call SubPacket.clear(msg);
    getHeader(msg) -> tproto = CX_INVALID_TP;
    getHeader(msg) -> distance = CX_INVALID_DISTANCE;
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) -
      sizeof(cx_transport_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    call SubPacket.setPayloadLength(msg, len +
      sizeof(cx_transport_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() -
      sizeof(cx_transport_header_t);
  }

  command void* Packet.getPayload(message_t* msg, 
      uint8_t len){
    void* pl = call SubPacket.getPayload(msg,
      len + sizeof(cx_transport_header_t));
    if (pl){
      return pl + sizeof(cx_transport_header_t);
    }else{
      return pl;
    }
  }

  command uint8_t CXTransportPacket.getDistance(message_t* msg){
    return (getHeader(msg) -> distance);
  }

  command uint8_t CXTransportPacket.getProtocol(message_t* msg){
    return (getHeader(msg) -> tproto) & CX_TP_PROTO_MASK;
  }
  command uint8_t CXTransportPacket.getSubprotocol(message_t* msg){
    return (getHeader(msg) -> tproto) & ~CX_TP_PROTO_MASK;
  }

  command void CXTransportPacket.setDistance(message_t* msg,
      uint8_t distance){
    getHeader(msg) -> distance = distance;
  }
  command void CXTransportPacket.setProtocol(message_t* msg,
      uint8_t tproto){
    uint8_t tp = getHeader(msg)->tproto;
    getHeader(msg)->tproto = (tproto & CX_TP_PROTO_MASK) | (tp & ~CX_TP_PROTO_MASK);
  }

  command void CXTransportPacket.setSubprotocol(message_t* msg,
      uint8_t subproto){
    uint8_t tp = getHeader(msg)->tproto;
    getHeader(msg)->tproto = (tp & CX_TP_PROTO_MASK) | (subproto & ~CX_TP_PROTO_MASK);
  }

}
