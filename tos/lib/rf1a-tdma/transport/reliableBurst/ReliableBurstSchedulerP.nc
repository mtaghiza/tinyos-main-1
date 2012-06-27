 #include "schedule.h"
module ReliableBurstSchedulerP{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule;
  uses interface SlotStarted;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
} implementation {
  enum {
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

  command error_t AMSend.send[am_id_t id](am_addr_t addr, 
      message_t* msg, uint8_t len){
    //ugh. this is to handle the case where AMSend.send is called from
    //some other component's SlotStarted event BEFORE our
    //SlotStarted event has fired and set up for the new slot.
//    printf_TMP("am\r\n");
    newSlot(call SlotStarted.currentSlot());
    //unicast only
    if (addr == AM_BROADCAST_ADDR){
      return EINVAL;
    } else {
      error_t error;
      call AMPacket.setType(msg, id);
      call AMPacketBody.setPayloadLength(msg, len);
      call CXPacket.setDestination(msg, addr);
      call CXPacketMetadata.setRequiresClear(msg, TRUE);

      //Idle or ready (but for a different destination):
      //  We need to set up a new route
      if (state == S_IDLE || (state == S_READY && addr != lastDest)){
        call CXPacket.setNetworkProtocol(msg, CX_RM_NONE);
//        printf_TMP("sfs.sn\r\n");
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          state = S_SETUP;
        }
      //sending along an established set of paths
      } else if (state == S_READY && addr == lastDest){
        call CXPacket.setNetworkProtocol(msg, CX_RM_PREROUTED);
//        printf_TMP("sfs.sP\r\n");
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          state = S_SENDING;
        }
      }else{
        printf("!RB.S: sending\r\n");
        error = EBUSY;
      }
      //SUCCESS: OK, we're going to send it. 
      //RETRY: not enough time in this slot
      if (error != SUCCESS && error != ERETRY){
        state = S_ERROR_0;
        printf("!RB.S: Error: %s\r\n", decodeError(error));
      }
      return error;
    }
  }
  
  event void ScopedFloodSend.sendDone(message_t* msg, error_t error){
//    printf_TMP("RB.sfs.sd\r\n");
    if (state != S_SETUP && state != S_READY){
      printf("!RB.SFS.sd: in %x expected %x\r\n", state, S_SETUP);
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
    signal AMSend.sendDone[call AMPacket.type(msg)](msg, error);
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload, uint8_t len){
    return signal Receive.receive[call AMPacket.type(msg)](msg, payload, len);
  }
  
  async command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched(frameNum) &&
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
      //in some cases, we can end up getting the slotStarted event
      //before seeing the sendDone event (even though the last
      //transmission did not violate a slot boundary)
      //e.g. at frame 98 we supply a packet. it gets sent in frame 99.
      //when frame 100 starts (new slot), the flood layer posts a task
      //to signal sendDone, but directly signals the slotStarted event.
      if (state == S_READY){
        state = S_IDLE;
      }else if (state != S_IDLE){
        printf("!RB.SS.SS in %x\r\n", state);
        state = S_ERROR_3;
      }
    }
  }

  event void SlotStarted.slotStarted(uint16_t slotNum){
//    printf_TMP("ss\r\n");
    newSlot(slotNum);
  }

  command error_t AMSend.cancel[am_id_t id](message_t* msg){
    return FAIL;
  }

  command uint8_t AMSend.maxPayloadLength[am_id_t id](){
    return call AMPacketBody.maxPayloadLength();
  }

  command void* AMSend.getPayload[am_id_t id](message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }


} 
