module CombineReceiveP{
  provides interface Receive[am_id_t id];
  uses interface Receive as SimpleFloodReceive[am_id_t id];
  uses interface Receive as UnreliableBurstReceive[am_id_t id];
} implementation {
  event message_t* SimpleFloodReceive.receive[am_id_t id](message_t* msg, void* payload,
      uint8_t len){
    return signal Receive.receive[id](msg, payload, len);
  }
  event message_t* UnreliableBurstReceive.receive[am_id_t id](message_t* msg, void* payload,
      uint8_t len){
    return signal Receive.receive[id](msg, payload, len);
  }

  default event message_t* Receive.receive[am_id_t id](message_t* msg,
      void* payload, uint8_t len){
    return msg;
  }
}
