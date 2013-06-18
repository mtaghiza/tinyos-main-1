
 #include "CXMac.h"
module CXMacPacketC {
  provides interface Packet;
  provides interface CXMacPacket;
  uses interface Packet as SubPacket;
} implementation {
  cx_mac_header_t* header(message_t* msg){
    return (cx_mac_header_t*)(call SubPacket.getPayload(msg, sizeof(cx_mac_header_t)));
  }

  command uint8_t CXMacPacket.getMacType(message_t* msg){
    return header(msg)->macType;
  }
  command void CXMacPacket.setMacType(message_t* msg, uint8_t macType){
    header(msg)->macType = macType;
  }

  command void Packet.clear(message_t* msg){
    call SubPacket.clear(msg);
    memset(header(msg), 0, sizeof(cx_mac_header_t));
    header(msg)->macType = CXM_DATA;
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len){
    return call SubPacket.getPayload(msg, 
      len + sizeof(cx_mac_header_t))+sizeof(cx_mac_header_t);
  }

  command uint8_t Packet.payloadLength(message_t* msg){
    return call SubPacket.payloadLength(msg) -
      sizeof(cx_mac_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, 
      uint8_t len){
    call SubPacket.setPayloadLength(msg, 
      len + sizeof(cx_mac_header_t));
  }

  command uint8_t Packet.maxPayloadLength(){
    return call SubPacket.maxPayloadLength() - sizeof(cx_mac_header_t);
  }
}
