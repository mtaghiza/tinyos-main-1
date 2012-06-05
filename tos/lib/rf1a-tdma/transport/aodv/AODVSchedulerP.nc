 #include "stateSafety.h"
 #include "AODVDebug.h"
 #include "FDebug.h"
module AODVSchedulerP{
//  provides interface TDMARoutingSchedule;
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule as SubTDMARoutingSchedule;
  uses interface FrameStarted;

  uses interface CXRoutingTable;

  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  
  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;
  
  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface CXPacket;
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

  uint16_t lastFn;
  

  //OK: take advantage of 1-deep queueing
  //If we're doing AODV, send the batch contents via Flood.send. When
  //  you get a sendDone, signal it up and immediately accept another
  //  packet and pass it to the flood layer. However, keep track of
  //  the isOrigin which you last responded TRUE to, and don't respond
  //  TRUE again until that time has been reached.
  //  additionally, do not accept any sends if they will not be able
  //  to be handled during your slot.
  command error_t AMSend.send[am_id_t id](am_addr_t addr, 
      message_t* msg, uint8_t len){
    am_addr_t destination; 
    error_t error;
    TMP_STATE;
    CACHE_STATE;
    printf_TMP("UBS.s %x\r\n", id);
    call AMPacket.setType(msg, id);
    call AMPacketBody.setPayloadLength(msg, len);
    call CXPacket.setDestination(msg, addr);
    destination = call CXPacket.destination(msg);
    printf_AODV_S("S %p to %x ", msg, destination);

    //broadcast: invalid (this is unicast only)
    if (destination == AM_BROADCAST_ADDR){
      return EINVAL;
    //unicast:
    // - sending along established path: prerouted + flood
    // - new: scoped flood
    } else {
      printf_AODV_S("U");
      //If we are idle OR if we have established a path, but there's
      //not enough time left to send another packet along it, we go to
      //AO_SETUP and stash the message in ScopedFloodSend.

      //TODO: some packets which we (should) know are destined for slot
      //  violation seem to be going to FloodSend. So, maybe we're not
      //  ending up in the AO_CLEARING_END state when we're supposed
      //  to.
      if (
        (CHECK_STATE(S_IDLE) || CHECK_STATE(S_AO_CLEARING_END)) 
        || 
        (CHECK_STATE(S_AO_READY) && (lastFn + aoClearTime >= nextSlotStart))
        ){ 
        printf_TMP("UBS: call sfs.s\r\n");
        printf_AODV_CLEAR("SF %u (%u)\r\n", lastFn, nextSlotStart);
        printf_AODV_S("S");
        call CXPacket.setNetworkProtocol(msg, CX_RM_NONE);
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          SET_STATE(S_AO_SETUP, S_ERROR_2);
        } 
      } else if (CHECK_STATE(S_AO_READY) || CHECK_STATE(S_AO_CLEARING)){
        printf_TMP("UBS: call fs.s\r\n");
        printf_AODV_S("P");
        if (destination == lastDestination){
          printf_AODV_CLEAR("F %u (%u %x)\r\n", lastFn, nextSlotStart, state);
          call CXPacket.setNetworkProtocol(msg, CX_RM_PREROUTED);
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
    printf_TMP("sfs.sd: %s\r\n", decodeError(error));
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
          *(call SubTDMARoutingSchedule.framesPerSlot()));
        aoClearTime = call CXRoutingTable.distance(TOS_NODE_ID, 
          call CXPacket.destination(msg)) 
          + call SubTDMARoutingSchedule.maxRetransmit();
        lastDestination = call CXPacket.destination(msg);

        //TODO: check this: we seem to be accepting packets that we
        //know will end in slot violation (sometimes), which would indicate that
        //this logic is wrong (ending up in S_AO_READY when we should
        //be going to S_IDLE)
        if (2*aoClearTime + lastStart >= nextSlotStart){
          printf_AODV_CLEAR("CI %u %u\r\n", aoClearTime, lastStart);
          //this would be the case where, for instance, we are so far
          //away from the destination that there's not time after the
          //initial path-establishment to do anything else.
          SET_STATE(S_IDLE, S_ERROR_3);
        } else {
          printf_AODV_CLEAR("CR %u %u\r\n", aoClearTime, lastStart);
          SET_STATE(S_AO_READY, S_ERROR_3);
        }
      }else{
        printf_AODV_S("Unexpected sfs.sd\r\n");
      }
    }
    signal AMSend.sendDone[call AMPacket.type(msg)](msg, error);
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
        printf_AODV_CLEAR("CE %u %u\r\n", aoClearTime, lastStart);
        SET_STATE(S_AO_CLEARING_END, S_ERROR_6);
      } else {
        printf_AODV_CLEAR("C %u %u\r\n", aoClearTime, lastStart);
        SET_STATE(S_AO_CLEARING, S_ERROR_6);
      }
      signal AMSend.sendDone[call AMPacket.type(msg)](msg, error);
    }
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid?
    return signal Receive.receive[call AMPacket.type(msg)](msg, payload, len);
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload, uint8_t len){
    //TODO: buffer it here to minimize risk of user app doing anything
    //  stupid?
    return signal Receive.receive[call AMPacket.type(msg)](msg, payload, len);
  }

  task void signalAborted(){
    TMP_STATE;
    CACHE_STATE;
    SET_STATE(S_IDLE, S_ERROR_5);
    signal AMSend.sendDone[call AMPacket.type(lastMsg)](lastMsg, ERETRY);
  }

  //only called from async context
  //return true if this is a valid point for a transmission to begin.
  // valid if:
  // - flooding AND start of our slot
  // - AO_SETUP AND start of our slot
  // - AO_WAIT and enough time has elapsed for the last ao packet to
  //   have cleared.
  bool isOrigin(uint16_t frameNum){
    uint16_t fps = call SubTDMARoutingSchedule.framesPerSlot();
    TMP_STATE;
    CACHE_STATE;
    if (CHECK_STATE(S_AO_SETUP) && (frameNum == TOS_NODE_ID*fps)){
      SET_STATE(S_AO_SETUP_SENDING, S_ERROR_9);
      lastStart = frameNum;
      printf_AODV_IO("IO ASU %u\r\n", frameNum);
      printf_TMP("io %u ", frameNum);
      printf_TMP("SUT\r\n");
      return TRUE;
    } 
    //TODO: if the pending message is being sent with acks
    //(scoped-flood) then we should only return true if it's a data
    //frame  (localFrame%3==0)
    if (CHECK_STATE(S_AO_PENDING)){
      printf_TMP("io %u ", frameNum);
      printf_TMP("PT\r\n");
      printf_AODV_IO("IO AP %u\r\n", frameNum);
      SET_STATE(S_AO_SENDING, S_ERROR_a);
      lastStart = frameNum;
      return TRUE;
    }
//    printf_AODV("IOX %u\r\n", frameNum);
    return FALSE;
  }
  
  uint16_t abortFn;
  task void reportAbort(){
    printf_AODV_CLEAR("Abort: %u\r\n", abortFn);
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    TMP_STATE;
    bool lastCleared = (frameNum >= (aoClearTime + lastStart));
    bool noTimeLeft = ((aoClearTime + frameNum) >= nextSlotStart);
    lastFn = frameNum;
    CACHE_STATE;

    if (CHECK_STATE(S_AO_CLEARING) && lastCleared){
//      if (noTimeLeft){
//        setState(S_IDLE, S_ERROR_c);
//      }else{
        SET_STATE(S_AO_READY, S_ERROR_c);
//      }
//      return;
    }    
    
    if (CHECK_STATE(S_AO_READY) && noTimeLeft){
      abortFn = frameNum;
      post reportAbort();
      SET_STATE(S_IDLE, S_ERROR_c);
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

  //origin if:
  //- we're synched AND
  //- one of the following holds
  //  - root scheduler says "yeah, it's an origin frame" (e.g. it
  //    wants to send a schedule announcement or reply
  //  - AODV internal logic figures "OK, it's cool to send a new data
  //    frame now."
  async command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
//    printf_AODV_IO("io %x %u\r\n", rm, frameNum);
    //TODO: We can get in trouble here: if we lose synchronization while we
    //are holding the resource, we can get into a deadlock.  The node
    //will never forward the message they're currently holding
    //(freeing the resource), and if the resource is not available,
    //the flood component will drop any incoming data packets,
    //including the schedule with which we need to synch.
    return (call SubTDMARoutingSchedule.isSynched(frameNum)) &&
      (isOrigin(frameNum) );
  }

//  //TODO schedule assignment: have to get away from using this for the
//  //general case: we should be able to identify slot boundaries and
//  //which frames belong to us, but not schedule for other nodes
//  async command bool TDMARoutingSchedule.ownsFrame(am_addr_t nodeId,
//      uint16_t frameNum){
//    uint16_t fps = call SubTDMARoutingSchedule.framesPerSlot();
//    //TODO: should this be nodeId+1? or does 0 just never get to send
//    //  except for schedule?
//    
//    //fps<=1: for special case of when we haven't received any
//    //schedules yet. it's not perfect...
//    return (fps <= 1) ||((frameNum >= (nodeId*fps)) 
//      && (frameNum < ((nodeId+1)*fps)));
//  }

//  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
////    printf_SCHED("aodv.mr\r\n");
//    return call SubTDMARoutingSchedule.maxRetransmit();
//  }
//  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
//    return call SubTDMARoutingSchedule.framesPerSlot();
//  }
  command error_t AMSend.cancel[am_id_t id](message_t* msg){
    return FAIL;
  }
  command void* AMSend.getPayload[am_id_t id](message_t* msg, uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }
  command uint8_t AMSend.maxPayloadLength[am_id_t id](){
    return call AMPacketBody.maxPayloadLength();
  }

  default event void AMSend.sendDone[am_id_t id](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t id](message_t* msg,
      void* paylod, uint8_t len){
    return msg;
  }

}
