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

    S_IDLE = 0x00,
    S_FLOODING = 0x01,
    S_AO_SETUP = 0x02,
    S_AO_READY = 0x03,
    S_AO_PENDING = 0x04,
    S_AO_WAIT = 0x05,
    S_AO_WAIT_PENDING = 0x06,
    S_AO_SENDING = 0x07,
    S_AO_WAIT_END = 0x08,
  };
  uint8_t state = S_IDLE;
  SET_STATE_DEF
  
  //book-keeping for AODV
  message_t* lastMsg;
  am_addr_t lastDestination = AM_BROADCAST_ADDR;
  uint16_t lastSF;
  uint8_t sfDepth;

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
    printf("aodv %u\r\n", len);
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
    // accept if we're IDLE, AO_READY, or AO_WAIT.
    } else {
      printf_AODV_S("U");
      if (CHECK_STATE(S_IDLE) || CHECK_STATE(S_AO_WAIT_END)){ 
        printf_AODV_S("S");
        call CXPacket.setRoutingMethod(msg, CX_RM_NONE);
        error = call ScopedFloodSend.send(msg, len);
        if (error == SUCCESS){
          SET_STATE(S_AO_SETUP, S_ERROR_2);
        } 
      } else if( CHECK_STATE(S_AO_READY) || CHECK_STATE(S_AO_WAIT)){
        if (destination == lastDestination){
          printf_AODV_S("P");
          call CXPacket.setRoutingMethod(msg, CX_RM_PREROUTED);
          error = call FloodSend.send(msg, len);
          if (error == SUCCESS){
            lastMsg = msg;
            if (CHECK_STATE(S_AO_READY)){
              SET_STATE(S_AO_PENDING, S_ERROR_4);
            }else if (CHECK_STATE(S_AO_WAIT)){
              SET_STATE(S_AO_WAIT_PENDING, S_ERROR_4);
            }
          }
        }else {
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
    printf_AODV_S("SFS.sd\r\n");
    if (ENOACK == error){
      lastDestination = AM_BROADCAST_ADDR;
      SET_STATE(S_IDLE, S_ERROR_3);
    } else {
      SET_STATE(S_AO_READY, S_ERROR_3);
      sfDepth = call CXRoutingTable.distance(TOS_NODE_ID, 
        call CXPacket.destination(msg));
      lastDestination = call CXPacket.destination(msg);
    }
    signal Send.sendDone(msg, error);
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
    TMP_STATE;
    CACHE_STATE;
    printf_AODV_S("FS.sd: %s\r\n", decodeError(error));
    if (CHECK_STATE(S_AO_SENDING)){
      uint16_t clearTime = sfDepth + call SubTDMARoutingSchedule.maxRetransmit[0]();
      //if there is not enough time to handle another packet, go to
      //WAIT_END state. if the app tries to send another packet,
      //we'll queue it in ScopedFloodSend until the cycle completes.
      //if we get a framestarted before it gets sent, then we'll go
      //back to idle as usual.
      if (2*clearTime + lastSF 
          >= (1+TOS_NODE_ID)*(call SubTDMARoutingSchedule.framesPerSlot[0]())){
        SET_STATE(S_AO_WAIT_END, S_ERROR_6);
      } else {
        SET_STATE(S_AO_WAIT, S_ERROR_6);
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
    if ((state == S_FLOODING) && (frameNum == TOS_NODE_ID*fps)){
      printf_AODV_IO("IO F %u\r\n", frameNum);
      return TRUE;
    }
    if ((state == S_AO_SETUP) && (frameNum == TOS_NODE_ID*fps)){
      state = S_AO_SENDING;
      printf_AODV_IO("IO ASU %u\r\n", frameNum);
      return TRUE;
    } 
    if (state == S_AO_PENDING){
      printf_AODV_IO("IO AP %u\r\n", frameNum);
      state = S_AO_SENDING;
      lastSF = frameNum;
      return TRUE;
    }
//    printf_AODV("IOX %u\r\n", frameNum);
    return FALSE;
  }
  
  async event void FrameStarted.frameStarted(uint16_t frameNum){
    if (state == S_AO_WAIT || state == S_AO_READY 
        || state == S_AO_WAIT_PENDING ){
      uint16_t clearTime =  sfDepth + 
        call SubTDMARoutingSchedule.maxRetransmit[0]();
      printf_AODV("<%u %x>\r\n", frameNum, state);

      //last packet is clear, ready to go again.
      if (clearTime + lastSF < frameNum){
        //AO_WAIT->AO_READY
        //AO_PENDING->AO_SENDING
        if (state == S_AO_WAIT){
          printf_AODV("cleared->r\r\n");
          state = S_AO_READY;
        }else if (state == S_AO_WAIT_PENDING){
          printf_AODV("cleared->p\r\n");
          state = S_AO_PENDING;
        }else if (state == S_AO_READY){
          //OK, no change.
        } else {
          printf_AODV("fs?\r\n");
        }
      }

      //no time to send any more, so go back to idle. Also clear out
      //  leftover state
      if (clearTime + frameNum 
          >= (1+TOS_NODE_ID)*(call SubTDMARoutingSchedule.framesPerSlot[0]())){
        printf_AODV("to idle (%u >= %u)\r\n", 
          clearTime+frameNum,
          (1+TOS_NODE_ID)*(call SubTDMARoutingSchedule.framesPerSlot[0]()));
        state = S_IDLE;
        lastSF = 0;
        lastDestination = AM_BROADCAST_ADDR;
        sfDepth = 0xff;

      } 
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
//    printf_AODV("io %x %u\r\n", rm, frameNum);
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
