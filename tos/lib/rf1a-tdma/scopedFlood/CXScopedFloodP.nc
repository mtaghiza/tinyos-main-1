
 #include "Rf1a.h"
 #include "CXFlood.h"
module CXScopedFloodP{
  provides interface Send[am_id_t t];
  provides interface Receive[am_id_t t];

  uses interface CXPacket;
  //Payload: body of CXPacket
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
  uses interface Resource;
} implementation {
  enum{
    S_IDLE = 0x00,
    S_ORIGIN        = 0x11,
    S_ORIGIN_START  = 0x13,
    S_FWD  = 0x14,

    ACTIVE = 0x10,
  };

  uint8_t dataState = S_IDLE;
  message_t* origin_msg;
  uint8_t origin_len;
  
  message_t data_msg_internal;
  message_t* data_msg = & data_msg_internal;

  uint8_t data_len;

  bool originPending;

  uint8_t ackState = S_IDLE;
  message_t* ack_msg;
  uint8_t ack_len;

  message_t own_ack_internal;
  message_t* own_ack_msg = &own_ack_internal;

  message_t ack_internal;
  message_t* ack_msg = &ack_internal;

  //receive(d)   -> swap to data_msg
  //receive(a)   -> swap to ack_msg
  //generate-ack -> swap ownAck with ack_msg
  //send-data    -> store separately

  uint16_t framesPerSlot;

  bool isDataFrame(uint16_t frameNum){
    uint16_t slotStart = frameNum % framesPerSlot;
    uint16_t offset = frameNum - slotStart;
    return ((offset % 3) == 0);
  }

  bool isOriginFrame(uint16_t frameNum){
    return (frameNum == (framesPerSlot* TOS_NODE_ID));
  }

  bool isAckFrame(uint16_t frameNum){
    return ! isDataFrame(frameNum);
  }

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
    if (!originPending){
      origin_msg = msg;
      origin_len = len + sizeof(cx_header_t);
      call CXPacket.init(msg);
      call CXPacket.setType(msg, t);
      call CXPacket.setRoutingMethod(msg, CX_RM_SCOPED_FLOOD);
      originPending = TRUE;
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }
  
  command error_t Send.cancel[am_id_t t](message_t* msg){
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    if (originPending && isOriginFrame(frameNum)){
      if (!(dataState & ACTIVE)){
        call Resource.immediateRequest();
        dataTXLeft = maxRetransmit;
        dataState = S_ORIGIN_START;
        return RF1A_OM_FSTXON;
      }else{
        //busy already, so leave it. This shouldn't happen if all the
        //nodes are scheduled properly.
      }
    }

    if (isDataFrame(frameNum) 
        && (dataState & ACTIVE )){
      return RF1A_OM_FSTXON;  
    } else if (isAckFrame(frameNum)
        && (ackState & ACTIVE )){
      return RF1A_OM_FSTXON;
    }
    return RF1A_OM_RX;
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    if (isDataFrame(frameNum)){
      if ((dataState & S_ORIGIN) == S_ORIGIN ){
        *msg = origin_data_msg;
        *len = origin_data_len;
      } else{
        *msg = data_msg;
        *len = data_len;
      }
      return TRUE;
    } else if (isAckFrame(frameNum)){
      if ((ackState & S_ORIGIN) === S_ORIGIN){
        *msg = origin_ack_msg;
        *len = origin_ack_len;
      } else {
        *msg = ack_msg;
        *len = ack_len;
      }
      return TRUE;
    }
    return FALSE;
  }

  task void signalSendDone(){
    originPending = FALSE;
    signal Send.sendDone[call CXPacket.type(origin_msg)](origin_msg, SUCCESS);
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (isDataFrame(frameNum)){
      if (dataState == S_ORIGIN_START){
        dataTXLeft = maxRetransmit;
        dataState = S_ORIGIN;
      }
      dataTXLeft--;
      if (dataTXLeft == 0){
        if((dataState & S_ORIGIN) == S_ORIGIN){
          post signalSendDone();
        }
        dataState = S_IDLE;
      }
    }else if (isAckFrame(frameNum)){
      if (ackState == S_ORIGIN_START){
        ackState = S_ORIGIN;
        ackTXLeft = maxRetransmit;
      }
      ackTXLeft--;
      if (ackTXLeft == 0){
        ackState = S_IDLE;
      }
    }
  }


  uint16_t lastDataSrc;
  uint8_t lastDataSn;

  uint16_t lastAckSrc;
  uint8_t lastAckSn;

  uint16_t ackedDataSrc;
  uint8_t ackedDataSn;

  //generate an ack, get a new RX buffer, and ready for sending acks.
  task void processReceive(){
    atomic{
      if (rxOutstanding){
        cx_ack_t* ack = (cx_ack_t*)(call LayerPacket.getPayload(ownAck,
          sizeof(cx_ack_t)));

        call CXPacket.init(ownAck);
        call CXPacket.setType(ownAck, CX_TYPE_ACK);
        call CXPacket.setRoutingMethod(ownAck, CX_RM_SCOPED_FLOOD);
        ack -> src = call CXPacket.source(rx_msg);
        ack -> sn  = call CXPacket.sn(rx_msg);
        ack -> depth = call CXPacket.count(rx_msg);

        ack_msg = ownAck;
        ack_len = sizeof(cx_header_t) + sizeof(cx_ack_t);

        rx_msg = signal Receive.receive[call CXPacket.type(rx_msg)](
          rx_msg, 
          call LayerPacket.getPayload(rx_msg, rx_len- sizeof(cx_header_t)),
          rx_len - sizeof(cx_header_t));

        ackState = S_ORIGIN_START;
        rxOutstanding = FALSE;
      }
    }
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    am_id_t pType = call CXPacket.type(msg);
    uint8_t sn = call CXPacket.sn(msg);
    am_addr_t src = call CXPacket.source(msg);
    am_addr_t dest = call CXPacket.destination(msg);

    //Type == Data
    if (pType == CX_TYPE_DATA){
      //duplicate data? -> return it. no change.
      if ((src == lastDataSrc) && (sn == lastDataSn)){
        return msg;

      //Matching Ack record? -> return it. no change to states.
      } else if( (src == ackedDataSrc) && (sn == ackedDataSn) ){
        return msg;

      //For me? -> swap it for rx and generate an ACK. ackState =
      //           s_origin_start
      } else if(dest == TOS_NODE_ID){
        if ( !rxOutstanding){
          message_t* swap = rx_msg;
          rxOutstanding = TRUE;
          rx_msg = msg;
          rx_len = len;
          post processReceive();
          return swap;
          
        } else {
          printf("rx busy!\r\n");
          //TODO: handle error case. busy processing last RX. We just
          //drop it, which will def. cause problems (as the scoped
          //flood will no longer extinguish itself)
          return msg;
        }
      //New?  -> Store the src, dest, and count, set flag on it. swap it to
      //         data_msg. dataState = s_new
      } else {
        lastDataSrc = src;
        lastDataSn = sn;
        lastDataDepth = call CXPacket.count(msg);
        data_msg = msg;
        data_len = len;
        dataTXLeft = maxRetransmit;
        dataState = S_FWD;
      }

    //Type == Ack
    } else if (call CXPacket.type(msg) == CX_TYPE_ACK){

    //duplicate ack?  -> return it. no change
    //No matching data record? -> return it. no state change.
    //Matching data,uncleared -> update the route info, swap it to ack_msg.
    //                 ackState = s_new. clear matching data flag.
    //for me?       -> post task to indicate was-acked. swap to
    //                 ack_msg. ackstate = s_new
    }
    return msg;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
    framesPerSlot = framesPerSlot_;
    maxRetransmit = maxRetransmit_;
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

}
