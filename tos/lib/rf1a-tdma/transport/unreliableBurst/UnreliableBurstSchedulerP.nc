 #include "schedule.h"
module UnreliableBurstSchedulerP{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule;
  uses interface SlotStarted;

  provides interface Send;
  provides interface Receive;

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  
  uses interface CXRoutingTable;
} implementation {
  enum {
    M_ERROR = 0x10,
    S_ERROR_0 = 0x10,
    S_ERROR_1 = 0x11,
    S_ERROR_2 = 0x12,
    S_ERROR_3 = 0x13,

    S_IDLE = 0x00,
    S_SETUP = 0x01,
    S_READY = 0x02,
    S_SENDING = 0x03,
  };

  uint8_t state = S_IDLE;
  am_addr_t lastDest = AM_BROADCAST_ADDR;
  uint16_t curSlot = INVALID_SLOT;
  
  void newSlot(uint16_t slotNum);

  command error_t Send.send(message_t* msg, uint8_t len){
    //ugh. this is to handle the case where AMSend.send is called from
    //some other component's SlotStarted event BEFORE our
    //SlotStarted event has fired and set up for the new slot.
    am_addr_t addr = call CXPacket.destination(msg);
//    printf_TMP("am\r\n");
    if (state & M_ERROR){
      return FAIL;
    }
    newSlot(call SlotStarted.currentSlot());
    //unicast only
    if (addr == AM_BROADCAST_ADDR){
      return EINVAL;
    } else {
      error_t error;
      call CXPacketMetadata.setRequiresClear(msg, TRUE);
      call CXPacket.setTransportType(msg, CX_TYPE_DATA);

      //Idle or ready (but for a different destination):
      //  We need to set up a new route
      if (state == S_IDLE || (state == S_READY && addr != lastDest)){
        call CXPacket.setNetworkProtocol(msg, CX_NP_NONE);
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          state = S_SETUP;
        }
      //sending along an established set of paths
      } else if (state == S_READY && addr == lastDest){
        call CXPacket.setNetworkProtocol(msg, CX_NP_PREROUTED);
        error = call FloodSend.send(msg, len);
        if (error == SUCCESS){
          state = S_SENDING;
        }
      }else{
        printf("!UB.S: sending\r\n");
        error = EBUSY;
      }
      //SUCCESS: OK, we're going to send it. 
      //RETRY: not enough time in this slot
      if (error != SUCCESS && error != ERETRY){
        state = S_ERROR_0;
        printf("!UB.S: Error: %s\r\n", decodeError(error));
      }
      printf_TMP("UB.S: %s\r\n", decodeError(error));
      return error;
    }
  }
  
  event void ScopedFloodSend.sendDone(message_t* msg, error_t error){
    if (state != S_SETUP){
      printf("!UB.SFS.sd: in %x expected %x\r\n", state, S_SETUP);
      state = S_ERROR_1;
    } else {
      if (ENOACK == error){
        lastDest = AM_BROADCAST_ADDR;
        state = S_IDLE;
      }else {
        lastDest = call CXPacket.destination(msg);
        state = S_READY;
      }
    }
    signal Send.sendDone(msg, error);
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
    if (state != S_SENDING){
      printf("!UB.FS.sd: in %x expected %x\r\n", state, S_SENDING);
      state = S_ERROR_2;
    } else {
      state = S_READY;
    }
    signal Send.sendDone(msg, error);
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    return signal Receive.receive(msg, payload, len);
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload, uint8_t len){
    return signal Receive.receive(msg, payload, len);
  }

  command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched() &&
        call TDMARoutingSchedule.ownsFrame(frameNum)){
      return TRUE;
    }else{
      return FALSE;
    }
  }

  void newSlot(uint16_t slotNum){
    if (slotNum != curSlot){
      lastDest = AM_BROADCAST_ADDR;
      curSlot = slotNum;
//      printf_TMP("%u\r\n", curSlot);
      //in some cases, we can end up getting the slotStarted event
      //before seeing the sendDone event (even though the last
      //transmission did not violate a slot boundary)
      //e.g. at frame 98 we supply a packet. it gets sent in frame 99.
      //when frame 100 starts (new slot), the flood layer posts a task
      //to signal sendDone, but directly signals the slotStarted event.
      if (state == S_READY){
        state = S_IDLE;
      }else if (state != S_IDLE){
        if (state != S_ERROR_3){
          printf("!UB.SS.SS in %x\r\n", state);
        }
        state = S_ERROR_3;
      }
    }else{
//      printf_TMP("\r\n");
    }
  }

  event void SlotStarted.slotStarted(uint16_t slotNum){
//    printf_TMP("ss");
    newSlot(slotNum);
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call AMPacketBody.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }


} 
