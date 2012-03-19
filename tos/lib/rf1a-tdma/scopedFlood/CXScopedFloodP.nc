
 #include "Rf1a.h"
 #include "CXFlood.h"
 #include "SFDebug.h"
module CXScopedFloodP{
  provides interface Send[am_id_t t];
  provides interface Receive[am_id_t t];

  uses interface CXPacket;
  //Payload: body of CXPacket
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
  uses interface Resource;

  uses interface CXRoutingTable;
  uses interface CXSendScheduler;
} implementation {
  enum{
    S_IDLE = 0x00,

    S_DATA = 0x01,
    S_ACK_WAIT = 0x02,
    S_ACK = 0x03,
    S_ACK_PREPARE = 0x04,

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
  uint8_t origin_ack_len;

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
  uint8_t waitLeft;
  uint8_t maxRetransmit;

  //race condition guard variables
  bool routeUpdatePending;
  bool rxOutstanding;
  
  //for matching up acks with data
  uint16_t lastDataSrc;
  uint8_t lastDataSn;

  //route update variables
  uint8_t ruSrcDepth;
  uint8_t ruAckDepth;
  uint8_t ruDistance;
  uint16_t ruSrc;
  uint16_t ruDest;
  bool routeUpdatePending;
  
  //scheduling
  norace uint16_t framesPerSlot;

  //forward declarations
  task void signalSendDone();
  task void routeUpdate();
  
  void setState(uint8_t s){
    printf_SF_STATE("{%x->%x}\r\n", state, s);
    state = s;
  }
  uint16_t nextSlotStart(uint16_t frameNum){
    return (frameNum + framesPerSlot)/framesPerSlot;
  }

  bool isDataFrame(uint16_t frameNum){
    uint16_t localF = frameNum % framesPerSlot;
    return ((localF%3) == 0);
  }

  bool isAckFrame(uint16_t frameNum){
    return ! isDataFrame(frameNum);
  }

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
    atomic{
      if (!originDataPending){
        origin_data_msg = msg;
        origin_data_len = len + sizeof(cx_header_t);
        call CXPacket.init(msg);
        call CXPacket.setType(msg, t);
        call CXPacket.setRoutingMethod(msg, CX_RM_SCOPEDFLOOD);
        originDataPending = TRUE;
        return SUCCESS;
      } else {
        return EBUSY;
      }
    }
  }
  
  command error_t Send.cancel[am_id_t t](message_t* msg){
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
//    printf("ft %u ", frameNum);

    //check for end of ACK_WAIT and clean up 
    if (state == S_ACK_WAIT){
      waitLeft --;
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

    if (originDataPending && call CXSendScheduler.isOrigin(frameNum)){
      if (state == S_IDLE){
        //TODO: should move request/release of this resource into
        //functions that perform any necessary book-keeping.
        call Resource.immediateRequest();
        TXLeft = maxRetransmit;
        lastDataSrc = TOS_NODE_ID;
        lastDataSn = call CXPacket.sn(origin_data_msg);
        setState(S_DATA);
        isOrigin = TRUE;
        return RF1A_OM_FSTXON;
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
        break;
      case S_ACK:
        if (isAckFrame(frameNum)){
          return RF1A_OM_FSTXON;
        } else {
          return RF1A_OM_RX;
        }
        break;
      case S_IDLE:
        //fall-through
      case S_ACK_WAIT:
        return RF1A_OM_RX;
        break;
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
        printf_SF_GP("o");
        originDataSent = TRUE;
        *msg = origin_data_msg;
        *len = origin_data_len;
      } else{
        printf_SF_GP("f");
        *msg = fwd_msg;
        *len = fwd_len;
      }
      printf_SF_GP("\r\n");
      return TRUE;
    } else if (isAckFrame(frameNum)){
      printf_SF_GP("a");
      if (isOrigin){
        printf_SF_GP("o");
        *msg = origin_ack_msg;
        *len = origin_ack_len;
      } else {
        printf_SF_GP("f");
        *msg = fwd_msg;
        *len = fwd_len;
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
    }
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    TXLeft --;
    if (TXLeft == 0){
      if (state == S_DATA){
        waitLeft = nextSlotStart(frameNum) - frameNum;
        setState(S_ACK_WAIT);
      }else if (state == S_ACK){
        call Resource.release();
        if (originDataSent){
          post signalSendDone();
        }
        post routeUpdate();
        setState(S_IDLE);
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
        call CXRoutingTable.update(ruSrc, ruDest,
          ruDistance);
        call CXRoutingTable.update(ruSrc, TOS_NODE_ID, 
          ruSrcDepth);
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
        origin_ack_len = sizeof(cx_header_t) + sizeof(cx_ack_t);
        isOrigin = TRUE;
        TXLeft = maxRetransmit;

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
    uint8_t sn = call CXPacket.sn(msg);
    am_addr_t src = call CXPacket.source(msg);
    am_addr_t dest = call CXPacket.destination(msg);
    printf_SF_RX("rx %x ", state);

    if (state == S_IDLE){
      printf_SF_RX("i");
      //New data
      if (pType == CX_TYPE_DATA){
        message_t* ret;

        printf_SF_RX("d");
        //coming from idle: we are always going to need the resource.
        if ( SUCCESS != call Resource.immediateRequest()){
          printf_SF_RX("d RESOURCE BUSY!\r\n");
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
          TXLeft = maxRetransmit;
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
          printf_SF_RX("m");
          fwd_msg = msg;
          fwd_len = len;
          TXLeft = maxRetransmit;
          
          //record routing information (our distance from the ack
          //  origin, src->dest distance)
          ruSrc = ack->src;
          ruDest = src;
          ruAckDepth = call CXPacket.count(msg);
          ruDistance = ack->depth;
          routeUpdatePending = TRUE;

          //we got an ack to data we sent. hooray!
          if (dest == TOS_NODE_ID){
            printf_SF_RX("M");
            sendDoneError = SUCCESS;
            post signalSendDone();
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
    } else {
      printf("SF unhandled state %x!\r\n", state);
      return msg;
    }

  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
    atomic{
      framesPerSlot = framesPerSlot_;
      maxRetransmit = maxRetransmit_;
    }
//    printf("sr: fps %u mr %u\r\n", framesPerSlot, maxRetransmit);
  }

  async event void CXTDMA.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ 
    //I guess we don't really need this now.
  }

  event void Resource.granted(){}

  command void* Send.getPayload[am_id_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[am_id_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[am_id_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}

  default command bool CXSendScheduler.isOrigin(uint16_t frameNum){
    return frameNum == (TOS_NODE_ID * framesPerSlot);
  }

}
