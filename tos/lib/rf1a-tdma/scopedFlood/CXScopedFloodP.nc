
 #include "Rf1a.h"
 #include "CXFlood.h"
 #include "SchedulerDebug.h"
 #include "SFDebug.h"
module CXScopedFloodP{
  provides interface Send[am_id_t t];
  provides interface Receive[am_id_t t];

  uses interface CXPacket;
  uses interface AMPacket;
  //Payload: body of CXPacket
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface Resource;

  uses interface CXRoutingTable;
} implementation {
  enum{
    S_IDLE = 0x00,

    S_DATA = 0x01,
    S_ACK_WAIT = 0x02,
    S_ACK = 0x03,
    S_ACK_PREPARE = 0x04,

    S_CLEAR_WAIT = 0x05,

    S_ERROR = 0x10,

  };
  uint8_t state = S_IDLE;
  //TODO: might be easier to make this isAckOrigin and isDataOrigin
  //      or: clear it when switching to ACK if you're not the origin
  //for determining whether to use origin_xxx or fwd_msg
  bool isOrigin;

  //indicates that Send has requested data transmission at the next
  //available time.
  bool originDataPending;
  //indicates that we have sent the data requested by the Send
  //interface (so that we know to signal SendDone at some point).
  bool originDataSent;
  
  //acks which we generate in this layer
  message_t origin_ack_internal;
  message_t* origin_ack_msg = &origin_ack_internal;
  uint8_t origin_ack_len = sizeof(cx_header_t) + sizeof(cx_ack_t) +
    sizeof(rf1a_nalp_am_t);

  //local buffer for swapping with packets received from lower layer
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  //provided by Send interface. 
  message_t* origin_data_msg;
  uint8_t origin_data_len;
  error_t sendDoneError;
  
  //shared by forwarded data and forwarded acks.
  message_t fwd_msg_internal;
  message_t* fwd_msg = &fwd_msg_internal;
  uint8_t fwd_len;
  
  //for determining when to transition states
  uint8_t TXLeft;
  uint16_t waitLeft;

  //race condition guard variables
  bool routeUpdatePending;
  bool rxOutstanding;
  
  //for matching up acks with data and suppressing duplicate data
  //receptions
  uint16_t lastDataSrc;
  uint32_t lastDataSn;
  
  //for suppressing duplicate ack receptions.
  uint16_t lastAckSrc;
  uint32_t lastAckSn;

  //route update variables
  uint8_t ruSrcDepth;
  uint8_t ruAckDepth;
  uint8_t ruDistance;
  uint16_t ruSrc;
  uint16_t ruDest;
  bool routeUpdatePending;

  uint16_t originFrame;
  uint16_t ackFrame;
  

  //forward declarations
  task void signalSendDone();
  task void routeUpdate();
  
  void setState(uint8_t s){
    printf_SF_STATE("{%x->%x}\r\n", state, s);
    state = s;
  }
  uint16_t leftInSlot(uint16_t frameNum){
    uint16_t fps = call TDMARoutingSchedule.framesPerSlot();
    //left-in-slot: call TDMARoutingSchedule.framesPerSlot() - frameNum%(call TDMARoutingSchedule.framesPerSlot())
    return fps - frameNum%fps;
  }

  bool isDataFrame(uint16_t frameNum){
    uint16_t localF = frameNum % (call TDMARoutingSchedule.framesPerSlot());
    return ((localF%3) == 0);
  }

  bool isAckFrame(uint16_t frameNum){
    return ! isDataFrame(frameNum);
  }

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
//    printf_TESTBED("ScopedFloodSend\r\n");
    atomic{
      if (!originDataPending){
        origin_data_msg = msg;
        origin_data_len = len + sizeof(cx_header_t);
        call CXPacket.init(msg);
        call CXPacket.setType(msg, t);
        call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
        //preserve pre-routed bit
        call CXPacket.setRoutingMethod(msg, 
          ((call CXPacket.getRoutingMethod(msg)) & CX_RM_PREROUTED)
          | CX_RM_SCOPEDFLOOD);
        originDataPending = TRUE;
        return SUCCESS;
      } else {
        return EBUSY;
      }
    }
  }
  
  command error_t Send.cancel[am_id_t t](message_t* msg){
    //TODO: this should: 
    // - free the resource. 
    // - reset originDataPending to FALSE
    // - put us back into S_IDLE
    //if msg is NULL, this should
    //also signal sendDone to indicate what happened (so that we can
    //invoke this from a lower layer than the application sees).
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    //TODO: this should generally check for slot violations and
    //release the resource/return to idle if we're anything other than
    //idle.
//    printf("ft %u ", frameNum);
    //see notes in CXTDMA.sendDone. At this point, we have allowed
    //enough time to elapse for the frame to clear.
    //TODO: if this is prerouted, we don't need to wait this long. As
    //  soon as we get the ack, we can send in the next data frame.
    if (state == S_CLEAR_WAIT){
      //TODO: watch for slot length violations, quit if this is no
      //longer your slot.
      if (frameNum - ackFrame > (ackFrame - originFrame) + 1){
        post signalSendDone();
      }
    }
    //check for end of ACK_WAIT and clean up 
    if (state == S_ACK_WAIT){
      waitLeft --;
      printf_SF_TESTBED_AW("WL %u %u %u\r\n", frameNum, 
        call TDMARoutingSchedule.framesPerSlot(), 
        waitLeft);
      if (waitLeft == 0){
        isOrigin = FALSE;
        routeUpdatePending = FALSE;
        lastDataSrc = 0xffff;
        lastDataSn = 0;
        call Resource.release();
        //no ack by the end of the slot, done.
        if (originDataSent){
          sendDoneError = ENOACK;
          post signalSendDone();
        }
        //get ready for next slot
        setState(S_IDLE);
      }
    }

    if (originDataPending && call TDMARoutingSchedule.isOrigin(frameNum)){
      if (!isDataFrame(frameNum)){
        printf("!origin but non-data frame %u\r\n", frameNum);
      }
      if (state == S_IDLE){
        //TODO: should move request/release of this resource into
        //functions that perform any necessary book-keeping.
        if (SUCCESS == call Resource.immediateRequest()){
          TXLeft = call TDMARoutingSchedule.maxRetransmit();
          lastDataSrc = TOS_NODE_ID;
          lastDataSn = call CXPacket.sn(origin_data_msg);
          setState(S_DATA);
          isOrigin = TRUE;
          originFrame = frameNum;
          return RF1A_OM_FSTXON;
        } else {
          printf("!SF.ft.RIR\r\n");
          return RF1A_OM_RX;
        }
      }else{
        //busy already, so leave it. This shouldn't happen if all the
        //nodes are scheduled properly.
      }
    }

    switch (state){
      case S_DATA:
        if (isDataFrame(frameNum)){
          return RF1A_OM_FSTXON;
        } else {
          return RF1A_OM_RX;
        }
      case S_ACK:
        if (isAckFrame(frameNum)){
          return RF1A_OM_FSTXON;
        } else {
          return RF1A_OM_RX;
        }
      case S_CLEAR_WAIT:
        //TODO: can we actually be idle during this time? Should be
        //OK.
        return RF1A_OM_RX;
      case S_IDLE:
        return RF1A_OM_RX;
      case S_ACK_WAIT:
        return RF1A_OM_RX;
      default:
        return RF1A_OM_RX;
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 

    printf_SF_GP("gp");
    if (isDataFrame(frameNum)){
      printf_SF_GP("d");
      if (isOrigin ){
        SF_GPO_SET_PIN;
        printf_SF_GP("o");
        originDataSent = TRUE;
        *msg = origin_data_msg;
        *len = origin_data_len;
        SF_GPO_CLEAR_PIN;
      } else{
        SF_GPF_SET_PIN;
        printf_SF_GP("f");
        *msg = fwd_msg;
        *len = fwd_len;
        SF_GPF_CLEAR_PIN;
      }
      printf_SF_GP("\r\n");
      return TRUE;
    } else if (isAckFrame(frameNum)){
      printf_SF_GP("a");
      if (isOrigin){
        SF_GPO_SET_PIN;
        printf_SF_GP("o");
        *msg = origin_ack_msg;
        *len = origin_ack_len;
        SF_GPO_CLEAR_PIN;
      } else {
        SF_GPF_SET_PIN;
        printf_SF_GP("f");
        *msg = fwd_msg;
        *len = fwd_len;
        SF_GPF_CLEAR_PIN;
      }
      printf_SF_GP("\r\n");
      return TRUE;
    }
    printf("SF.GP!\r\n");
    return FALSE;
  }

  task void signalSendDone(){
    atomic{
      originDataPending = FALSE;
      originDataSent = FALSE;
      signal Send.sendDone[call CXPacket.type(origin_data_msg)](origin_data_msg, sendDoneError);
      call Resource.release();
      setState(S_IDLE);
    }
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    TXLeft --;
    if (TXLeft == 0){
      if (state == S_DATA){
        //TODO: if this is pre-routed, waitLeft should be just the
        //time required for the ack to come back (maybe + a little
        //fudge), not all the way to the end of the slot.
        //it would be ideal if these acks were done just with normal
        //back-to-back-floods, but what are you going to do.
        waitLeft = leftInSlot(frameNum);
        setState(S_ACK_WAIT);
      }else if (state == S_ACK){
        post routeUpdate();
        if (originDataSent){
          //if the data we sent was pre-routed, we're done right
          //now. Might be good to wait for another frame for anything
          //left to clear.
          if ( call CXPacket.getRoutingMethod(origin_data_msg) & CX_RM_PREROUTED){
            post signalSendDone();
          } else { 
            //otherwise, we have to wait for the air to clear.
            //if we got the ack n frames after our tx, then there are n
            //frames in the worst case for our forwarded ack to suppress
            //the edges of the flood. 
            //
            //      6 5 4 3 2 1 0 1 2 
            //  0               d
            //  1          
            //  2                
            //  3             d   d
            //  4                   a
            // *5                 a
            //  6           d
            //  7               a
            //  8             a
            //  9         d
            // 10           a
  
            setState(S_CLEAR_WAIT);
          }
        } else {
          call Resource.release();
          setState(S_IDLE);
        }
      }else{
        printf("!Unexpected state %x at sf.cxtdma.sendDone\r\n", state);
      }
    }
  }


  task void routeUpdate(){
    atomic{
      if (routeUpdatePending){
        //up to the routing table to do what it wants with it.
        // for AODV, all we really care about is whether we are
        // between the two: 
        //  src->me + me->dest  <= src->dest
//        printf_BF("them\r\n");
        call CXRoutingTable.update(ruSrc, ruDest,
          ruDistance);
//        printf_BF("src->me\r\n");
        call CXRoutingTable.update(ruSrc, TOS_NODE_ID, 
          ruSrcDepth);
//        printf_BF("dest->me\r\n");
        call CXRoutingTable.update(ruDest, TOS_NODE_ID,
          ruAckDepth);
        routeUpdatePending = FALSE;
      }
    }
  }

  //generate an ack, get a new RX buffer, and ready for sending acks.
  task void processReceive(){
    atomic{
      if (state == S_ACK_PREPARE){
        cx_ack_t* ack = (cx_ack_t*)(call LayerPacket.getPayload(origin_ack_msg, sizeof(cx_ack_t)));

        call CXPacket.init(origin_ack_msg);
        call CXPacket.setType(origin_ack_msg, CX_TYPE_ACK);
        call CXPacket.setRoutingMethod(origin_ack_msg, CX_RM_SCOPEDFLOOD);
        call CXPacket.setDestination(origin_ack_msg, call CXPacket.source(rx_msg));
        call CXPacket.setSource(origin_ack_msg, TOS_NODE_ID);
        ack -> src = call CXPacket.source(rx_msg);
        ack -> sn  = call CXPacket.sn(rx_msg);
        ack -> depth = call CXPacket.count(rx_msg);
//        printf_BF("su ack: %x %u %u\r\n", ack->src, ack->sn, ack->depth);
        isOrigin = TRUE;
        TXLeft = call TDMARoutingSchedule.maxRetransmit();
        //TODO: I am worried that this isn't running before getPacket
        //tries to get the origin ack.

        //route update goodness
        ruSrcDepth = call CXPacket.count(rx_msg);
        ruSrc = call CXPacket.source(rx_msg);
        ruAckDepth = 0;
        ruDistance = ruSrcDepth;
        routeUpdatePending = TRUE;

        rx_msg = signal Receive.receive[call CXPacket.type(rx_msg)](
          rx_msg, 
          call LayerPacket.getPayload(rx_msg, rx_len- sizeof(cx_header_t)),
          rx_len - sizeof(cx_header_t));
        setState(S_ACK);
      }
    }
  }


  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    am_id_t pType = call CXPacket.type(msg);
    uint32_t sn = call CXPacket.sn(msg);
    am_addr_t src = call CXPacket.source(msg);
    am_addr_t dest = call CXPacket.destination(msg);
    printf_SF_RX("rx %x ", state);
    if ( (pType == CX_TYPE_DATA && 
           (src == lastDataSrc && sn == lastDataSn))
       ||(pType == CX_TYPE_ACK &&
           (src == lastAckSrc && sn == lastAckSn)) 
       || (!call TDMARoutingSchedule.isSynched(frameNum))){
      //duplicate, or non-synched, drop it.
      return msg;
    }
    if (pType == CX_TYPE_DATA && ! call TDMARoutingSchedule.ownsFrame(src, frameNum)) {
      printf_SF_TESTBED("SV SF D %u %u\r\n", src, frameNum);
      return msg;
    } else if (pType== CX_TYPE_ACK && ! call TDMARoutingSchedule.ownsFrame(dest, frameNum)){
      printf_SF_TESTBED("SV SF A %u %u\r\n", dest, frameNum);
      return msg;
    }
           
    if (state == S_IDLE){
      printf_SF_RX("i");
      //drop pre-routed packets for which we aren't on a route.
      if (call CXPacket.getRoutingMethod(msg) & CX_RM_PREROUTED){
        bool isBetween;
        printf_SF_RX("p");
        if ((SUCCESS != call CXRoutingTable.isBetween(src, 
            call CXPacket.destination(msg), &isBetween)) || !isBetween){
          printf_SF_TESTBED_PR("PRD\r\n");
          printf_SF_RX("x*\r\n");
          return msg;
        }else{
          printf_SF_TESTBED_PR("PRK\r\n");
        }
      }
      //OK: the state guards us from overwriting rx_msg. the only time
      //that we write to it is when we are in idle.
      //New data
      if (pType == CX_TYPE_DATA){
        message_t* ret;

        printf_SF_RX("d");
        //coming from idle: we are always going to need the resource.
        if ( SUCCESS != call Resource.immediateRequest()){
          printf("!SF.r.RIR\r\n");
          return msg;
        }

        //record src/sn so we can match it to ack
        lastDataSrc = src;
        lastDataSn = sn;
        
        //record our distance from the data source.
        ruSrcDepth = call CXPacket.count(msg);

        //for me: save it for RX and prepare to send ack.
        if (dest == TOS_NODE_ID){
          printf_SF_RX("M");
          ret = rx_msg;
          rx_msg = msg;
          rx_len = len;
          post processReceive();
          setState(S_ACK_PREPARE);
        //not for me: forward it.
        }else {
          printf_SF_RX("f");
          ret = fwd_msg;
          fwd_msg = msg;
          fwd_len = len;
          TXLeft = call TDMARoutingSchedule.maxRetransmit();
          isOrigin = FALSE;
          setState(S_DATA);
        }
        printf_SF_RX("\r\n");
        return ret;

      //ignore acks for which we have seen no data: this happens at
      //the edge of the flood.
      } else if (pType == CX_TYPE_ACK){
        printf_SF_RX("a*\r\n");
        return msg;
           
      } else {
        printf("SF Unhandled CX type!\r\n");
        return msg;
      }
    } else if ((state == S_DATA) || (state == S_ACK_WAIT)){
      printf_SF_RX("d");
      //ignore data receptions
      if (pType == CX_TYPE_DATA){
        printf_SF_RX("d*\r\n");
        return msg;

      //ack: verify that it matches the data, handle according to
      //whether it's destined for us or not, start forwarding it.
      } else if (pType == CX_TYPE_ACK){
        cx_ack_t* ack = (cx_ack_t*) (call LayerPacket.getPayload(msg,
          sizeof(cx_ack_t)));
        printf_SF_RX("a");
        if ( (ack->src == lastDataSrc) && (ack->sn == lastDataSn) ){
          message_t* ret = fwd_msg;
          lastAckSrc = src;
          lastAckSn = sn;
          printf_SF_RX("m");
          fwd_msg = msg;
          fwd_len = len;
          TXLeft = call TDMARoutingSchedule.maxRetransmit();
          
          //record routing information (our distance from the ack
          //  origin, src->dest distance)
          ruSrc = ack->src;
          ruDest = src;
          ruAckDepth = call CXPacket.count(msg);
//          printf_BF("rx ack: %x %u %u\r\n", ack->src, ack->sn, ack->depth);
          ruDistance = ack->depth;
          routeUpdatePending = TRUE;

          //we got an ack to data we sent. hooray!
          if (dest == TOS_NODE_ID){
            ackFrame = frameNum;
            printf_SF_RX("M");
            sendDoneError = SUCCESS;
            //This should be taken care of when we finish forwarding
            //these acks. Better to signal it at that point anyway.
//            post routeUpdate();
//            post signalSendDone();
          }
          isOrigin = FALSE;
          setState(S_ACK);
          printf_SF_RX("\r\n");
          return ret;
        }else{
          printf_SF_RX("o*\r\n");
          return msg;
        }

      } else {
        printf("SF Unhandled CX type!\r\n");
        return msg;
      }
      
    } else if (state == S_ACK){
      printf_SF_RX("a*\r\n");
      //already in the ack stage, so we will just keep on ignoring
      //these.
      return msg;
    } else if (state == S_CLEAR_WAIT){
      //ignore this if we're waiting for the air to clear.
      return msg;
    } else {
      printf("SF unhandled state %x!\r\n", state);
      return msg;
    }

  }

  event void Resource.granted(){}

  command void* Send.getPayload[am_id_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[am_id_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[am_id_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}

}
