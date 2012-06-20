module CombineReceiveP{
  provides interface Receive[am_id_t id];
  uses interface Receive as SimpleFloodReceive[am_id_t id];
  uses interface Receive as UnreliableBurstReceive[am_id_t id];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Rf1aPacket;
  uses interface AMPacket;
} implementation {
  void printRX(message_t* msg){
    printf_APP("RX s: %u d: %u sn: %u c: %u r: %d l: %u\r\n", 
      call CXPacket.source(msg),
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      call CXPacketMetadata.getReceivedCount(msg),
      call Rf1aPacket.rssi(msg),
      call Rf1aPacket.lqi(msg)
      );
  }

  event message_t* SimpleFloodReceive.receive[am_id_t id](message_t* msg, void* payload,
      uint8_t len){
    printRX(msg);
    return signal Receive.receive[id](msg, payload, len);
  }
  event message_t* UnreliableBurstReceive.receive[am_id_t id](message_t* msg, void* payload,
      uint8_t len){
    printRX(msg);
    return signal Receive.receive[id](msg, payload, len);
  }

  default event message_t* Receive.receive[am_id_t id](message_t* msg,
      void* payload, uint8_t len){
    return msg;
  }
}
