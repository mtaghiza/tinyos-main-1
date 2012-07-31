module CombineReceiveP{
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];
  uses interface Receive as SubReceive[uint8_t tProto];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Rf1aPacket;
  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  provides interface ReceiveNotify;

  uses interface Queue<message_t*>;
  uses interface Pool<message_t>;
} implementation {
  void printRX(message_t* msg){
    printf_APP("RX s: %u d: %u sn: %u o: %u c: %u r: %d l: %u\r\n", 
      call CXPacket.source(msg),
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      call CXPacket.getOriginalFrameNum(msg),
      call CXPacketMetadata.getReceivedCount(msg),
      call Rf1aPacket.rssi(msg),
      call Rf1aPacket.lqi(msg)
      );
  }

  task void rxTask(){
    if (! call Queue.empty()){
      message_t* msg = call Queue.dequeue();
      uint8_t pll = call AMPacketBody.payloadLength(msg);
      void* pl = call AMPacketBody.getPayload(msg, pll);

      signal ReceiveNotify.received(call AMPacket.source(msg));
  
      //restore AM destination from CX header fields
      call AMPacket.setDestination(msg, call CXPacket.destination(msg));
      if (call AMPacket.isForMe(msg)){
        printRX(msg);
        msg = signal Receive.receive[call AMPacket.type(msg)](msg, pl, pll);
      }else{
        msg = signal Snoop.receive[call AMPacket.type(msg)](msg, pl, pll);
      }
      call Pool.put(msg);
      if (! call Queue.empty()){
        post rxTask();
      }
    }
  }

  event message_t* SubReceive.receive[uint8_t tProto](message_t* msg, void* payload,
      uint8_t len){
    if (call Pool.empty()){
      printf("!QD\r\n");
      return msg;
    } else {
      post rxTask();
      call Queue.enqueue(msg);
      return call Pool.get();
    }
  }

  default event message_t* Receive.receive[am_id_t id](message_t* msg,
      void* payload, uint8_t len){
    return msg;
  }
  default event message_t* Snoop.receive[am_id_t id](message_t* msg,
      void* payload, uint8_t len){
    return msg;
  }

  default event void ReceiveNotify.received(am_addr_t from){}
}
