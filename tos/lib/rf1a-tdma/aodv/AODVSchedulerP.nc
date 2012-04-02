 #include "stateSafety.h"
 #include "AODVDebug.h"
module AODVSchedulerP{
  provides interface TDMARoutingSchedule[uint8_t rm];
  uses interface TDMARoutingSchedule as SubTDMARoutingSchedule[uint8_t rm];
  uses interface FrameStarted;

  uses interface CXRoutingTable;

  provides interface Send;
  provides interface Receive;
  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;
} implementation {

  enum{
    S_ERROR_1 = 0x11,
    S_ERROR_2 = 0x12,
    S_ERROR_3 = 0x13,
    S_ERROR_4 = 0x14,
    S_ERROR_5 = 0x15,
    S_ERROR_6 = 0x16,
    S_ERROR_7 = 0x17,
    S_ERROR_8 = 0x18,
    S_ERROR_9 = 0x19,
    S_ERROR_a = 0x1a,
    S_ERROR_b = 0x1b,
    S_ERROR_c = 0x1c,

    S_IDLE = 0x00,
    S_FLOODING = 0x01,

    S_AO_SETUP = 0x02,
    S_AO_SETUP_SENDING = 0x03,
    S_AO_READY = 0x04,
    S_AO_PENDING = 0x05,
    S_AO_SENDING = 0x06,
    S_AO_CLEARING = 0x07,
    S_AO_CLEARING_END = 0x08,
    S_AO_CLEARING_PENDING = 0x09,
  };
  uint8_t state = S_IDLE;
//  SET_STATE_DEF
  bool setState(uint8_t from, uint8_t to, uint8_t error){
    atomic {
      printf_AODV_STATE("{%x ->", state);
      if (state == from){
        state = to;
      }else{
        state = error;
      }
      printf_AODV_STATE(" %x}\r\n", state);
      return state == to;
    }
  }
  //book-keeping for AODV
  message_t* lastMsg;
  am_addr_t lastDestination = AM_BROADCAST_ADDR;
  uint16_t nextSlotStart;
  uint16_t aoClearTime;
  uint16_t lastStart;
  

  //OK: take advantage of 1-deep queueing
  //If we're doing AODV, send the batch contents via Flood.send. When
  //  you get a sendDone, signal it up and immediately accept another
  //  packet and pass it to the flood layer. However, keep track of
  //  the isOrigin which you last responded TRUE to, and don't respond
  //  TRUE again until that time has been reached.
  //  additionally, do not accept any sends if they will not be able
  //  to be handled during your slot.
  command error_t Send.send(message_t* msg, uint8_t len){
    am_addr_t destination; 
    error_t error;
    TMP_STATE;
    CACHE_STATE;
    destination = call CXPacket.destination(msg);
    printf_AODV_S("S %p to %x ", msg, destination);
    //broadcast: flood
    if (destination == AM_BROADCAST_ADDR){
      printf_AODV_S("F");
      call CXPacket.setRoutingMethod(msg, CX_RM_NONE);
      error = call FloodSend.send(msg, len);
      if (error == SUCCESS){
        SET_STATE(S_FLOODING, S_ERROR_1);
      }else{
        SET_ESTATE(S_ERROR_1);
      }
      printf_AODV_S("%s\r\n", decodeError(error));
      return error;

    //unicast:
    // - sending along established path: prerouted + flood
    // - new: scoped flood
    } else {
      printf_AODV_S("U");
      //If we are idle OR if we have established a path, but there's
      //not enough time left to send another packet along it, we go to
      //AO_SETUP and stash the message in ScopedFloodSend.
      if (CHECK_STATE(S_IDLE) || CHECK_STATE(S_AO_CLEARING_END)){ 
        printf_AODV_S("S");
        call CXPacket.setRoutingMethod(msg, CX_RM_NONE);
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          SET_STATE(S_AO_SETUP, S_ERROR_2);
        } 
      } else if (CHECK_STATE(S_AO_READY) || CHECK_STATE(S_AO_CLEARING)){
        printf_AODV_S("P");
        if (destination == lastDestination){
          call CXPacket.setRoutingMethod(msg, CX_RM_PREROUTED);
          //TODO: if msg has ack-requested set, call
          //ScopedFloodSend.send instead.
          error = call FloodSend.send(msg, len);
          if (CHECK_STATE(S_AO_READY)){
            SET_STATE(S_AO_PENDING, S_ERROR_2);
          } else if (CHECK_STATE(S_AO_CLEARING)){
            SET_STATE(S_AO_CLEARING_PENDING, S_ERROR_2);
          }
        }else{
          error = FAIL;
          printf_AODV_S("mismatch");
        }
      } else {
        printf_AODV_S("busy\r\n");
        return EBUSY;
      }

      printf_AODV_S(" %x %s\r\n", state, decodeError(error));
      return error;
    }
  }

    //destination address == broadcast
    // - try to send it via flood: if we get EBUSY, buffer it and try
    //   again later (when?) This will happen for root if we try to
    //   send while the schedule announcement is pending.  Not sure
    //   how to make sure that schedule has priority.
    // - isOrigin: 
    //   - TRUE at start of slot 
    //   - since we don't know network depth, have to respond FALSE
    //     for other times (?)

    //destination address == unicast
    // IDLE
    // - send via scoped flood, wait for SendDone, signal up.
    //   - ENOACK -> back to idle
    //   - SUCCESS -> AO_READY
    // - isOrigin[flood]: 
    //   - IDLE: TRUE at start of slot.
    //   - AO_READY: TRUE 
    // AO_READY
    // - matches last destination -> AO_SENDING
    // AO_WAIT 
    // - matches last destination -> AO_PENDING
    // 
    // sendDone 
    // AO_SENDING -> AO_WAIT 
    //
    // isOrigin
    // AO_READY: TRUE

  //OK, so we need actually kind of a lot of info at this layer that
  //is not super-available
  // - distance (from ack)
  //   - actually, have this in the routing table. cool.
  // - frame starts, whether data is being sent or not (e.g. so that
  //   we know when to go back to idle or when to stop allowing
  //   AO transmissions)
  //   - actually: when we get send done from initial SF, we can start
  //     immediately. if the contract with isOrigin is something like
  //     "if it returns TRUE/success, then we're going to send" then
  //     we could use this. In that sense, as soon as initial SF
  //     completes, we can queue up the next send in the flood
  //     component
  

  //no-ack: back to idle. 
  //always: Signal it up.
  event void ScopedFloodSend.sendDone(message_t* msg, error_t error){
    TMP_STATE;
    CACHE_STATE;
    printf_AODV_S("SFS.sd: %u \r\n", lastStart);
    //TODO: if state is S_AO_SENDING, do the same check as fs.sd for
    //  CLEARING, but adjust time. ENOACK: still OK to stay in the
    //  S_AO_READY state.
    if (ENOACK == error){
      lastDestination = AM_BROADCAST_ADDR;
      SET_STATE(S_IDLE, S_ERROR_3);
    } else {
      if (CHECK_STATE(S_AO_SETUP_SENDING)){
        nextSlotStart = (
          (1+TOS_NODE_ID)
          *(call SubTDMARoutingSchedule.framesPerSlot[0]()));
        aoClearTime = call CXRoutingTable.distance(TOS_NODE_ID, 
          call CXPacket.destination(msg)) 
          + call SubTDMARoutingSchedule.maxRetransmit[0]();
        lastDestination = call CXPacket.destination(msg);

        if (2*aoClearTime + lastStart >= nextSlotStart){
          //this would be the case where, for instance, we are so far
          //away from the destination that there's not time after the
          //initial path-establishment to do anything else.
          SET_STATE(S_IDLE, S_ERROR_3);
        } else {
          SET_STATE(S_AO_READY, S_ERROR_3);
        }
      }else{
        printf_AODV_S("Unexpected sfs.sd\r\n");
      }
    }
    signal Send.sendDone(msg, error);
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
    TMP_STATE;
    CACHE_STATE;
    printf_AODV_S("FS.sd: %u \r\n", lastStart);
    if (CHECK_STATE(S_AO_SENDING)){
      //if there is not enough time to handle another packet, go to
      //WAIT_END state. if the app tries to send another packet,
      //we'll queue it in ScopedFloodSend until the cycle completes.
      //if we get a framestarted before it gets sent, then we'll go
      //back to idle as usual.
      if (2*aoClearTime + lastStart >= nextSlotStart){
        printf_AODV("CE\r\n");
        SET_STATE(S_AO_CLEARING_END, S_ERROR_6);
      } else {
        printf_AODV("C\r\n");
        SET_STATE(S_AO_CLEARING, S_ERROR_6);
      }
      signal Send.sendDone(msg, error);
    }else if (CHECK_STATE(S_FLOODING)){
      SET_STATE(S_IDLE, S_ERROR_6);
      signal Send.sendDone(msg, error);
    }
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid?
    return signal Receive.receive(msg, payload, len);
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload, uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid?
    return signal Receive.receive(msg, payload, len);
  }

  task void signalAborted(){
    TMP_STATE;
    CACHE_STATE;
    SET_STATE(S_IDLE, S_ERROR_5);
    signal Send.sendDone(lastMsg, ERETRY);
  }

  //only called from async context
  //return true if this is a valid point for a transmission to begin.
  // valid if:
  // - flooding AND start of our slot
  // - AO_SETUP AND start of our slot
  // - AO_WAIT and enough time has elapsed for the last ao packet to
  //   have cleared.
  bool isOrigin(uint8_t rm, uint16_t frameNum){
    uint16_t fps = call SubTDMARoutingSchedule.framesPerSlot[rm]();
    TMP_STATE;
    CACHE_STATE;
    if (CHECK_STATE(S_FLOODING) && (frameNum == TOS_NODE_ID*fps)){
      printf_AODV_IO("IO F %u\r\n", frameNum);
      return TRUE;
    }
    if (CHECK_STATE(S_AO_SETUP) && (frameNum == TOS_NODE_ID*fps)){
      SET_STATE(S_AO_SETUP_SENDING, S_ERROR_9);
      lastStart = frameNum;
      printf_AODV_IO("IO ASU %u\r\n", frameNum);
      return TRUE;
    } 
    //TODO: if the pending message is being sent with acks
    //(scoped-flood) then we should only return true if it's a data
    //frame  (localFrame%3==0)
    if (CHECK_STATE(S_AO_PENDING)){
      printf_AODV_IO("IO AP %u\r\n", frameNum);
      SET_STATE(S_AO_SENDING, S_ERROR_a);
      lastStart = frameNum;
      return TRUE;
    }
//    printf_AODV("IOX %u\r\n", frameNum);
    return FALSE;
  }


  async event void FrameStarted.frameStarted(uint16_t frameNum){
    TMP_STATE;
    bool lastCleared = (frameNum >= aoClearTime + lastStart);
    bool noTimeLeft = (aoClearTime + frameNum > nextSlotStart);
    CACHE_STATE;
    if (CHECK_STATE(S_AO_READY) && noTimeLeft){
      SET_STATE(S_IDLE, S_ERROR_c);
      return;
    }
    if (CHECK_STATE(S_AO_CLEARING) && lastCleared){
      SET_STATE(S_AO_READY, S_ERROR_c);
      return;
    }
    if (CHECK_STATE(S_AO_CLEARING_PENDING) && lastCleared){
      SET_STATE(S_AO_PENDING, S_ERROR_c);
      return;
    }
    if (CHECK_STATE(S_AO_CLEARING_END) && lastCleared){
      SET_STATE(S_IDLE, S_ERROR_c);
      return;
    }
  }

  async command bool TDMARoutingSchedule.isSynched[uint8_t rm](uint16_t frameNum){
    return call SubTDMARoutingSchedule.isSynched[rm](frameNum);
  }
  
  //origin if:
  //- we're synched AND
  //- one of the following holds
  //  - root scheduler says "yeah, it's an origin frame" (e.g. it
  //    wants to send a schedule announcement or reply
  //  - AODV internal logic figures "OK, it's cool to send a new data
  //    frame now."
  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
    printf_AODV_IO("io %x %u\r\n", rm, frameNum);
    //TODO: We can get in trouble here: if we lose synchronization while we
    //are holding the resource, we can get into a deadlock.  The node
    //will never forward the message they're currently holding
    //(freeing the resource), and if the resource is not available,
    //the flood component will drop any incoming data packets,
    //including the schedule with which we need to synch.
    return (call SubTDMARoutingSchedule.isSynched[rm](frameNum)) &&
      (call SubTDMARoutingSchedule.isOrigin[rm](frameNum) ||
        isOrigin(rm, frameNum) );
  }

  async command uint8_t TDMARoutingSchedule.maxRetransmit[uint8_t rm](){
//    printf_SCHED("aodv.mr\r\n");
    return call SubTDMARoutingSchedule.maxRetransmit[rm]();
  }
  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return call SubTDMARoutingSchedule.framesPerSlot[rm]();
  }
  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }
  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

}
