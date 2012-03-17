
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
    S_IDLE = 0x01,
    S_NEW  = 0x02,
    S_FWD  = 0x03,

    ACTIVE = 0x02,
  };

  uint8_t dataState;
  message_t* origin_msg;
  uint8_t origin_len;
  message_t* data_msg;
  uint8_t data_len;

  bool originPending;

  uint8_t ackState;
  message_t* ack_msg;
  uint8_t ack_len;

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
        originSending = TRUE;
        data_msg = origin_msg;
        data_len = origin_len;
        call Resource.immediateRequest();
        dataTXLeft = maxRetransmit;
        dataState = S_NEW;
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
      *msg = data_msg;
      *len = data_len;
      return TRUE;
    } else if (isAckFrame(frameNum)){
      *msg = ack_msg;
      *len = ack_len;
      return TRUE;
    }
    return FALSE;
  }

  task void signalSendDone(){
    originSending = FALSE;
    originPending = FALSE;
    signal Send.sendDone[call CXPacket.type(origin_msg)](origin_msg, SUCCESS);
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (isDataFrame(frameNum)){
      if (dataState == S_NEW){
        dataState = S_FWD;
        dataTXLeft = maxRetransmit;
      }
      dataTXLeft--;
      if ((dataTXLeft == 0) && originSending){
        dataState = S_IDLE;
        post signalSendDone();
      }
    }else if (isAckFrame(frameNum)){
      if (ackState == S_NEW){
        ackState = S_FWD;
        ackTXLeft = maxRetransmit;
      }
      ackTXLeft--;
      if (ackTXLeft == 0){
        ackState = S_IDLE;
      }
    }
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    //Type == Data
    //duplicate data? -> return it. no change.
    //Matching Ack record? -> return it. no change to states.
    //For me?     -> swap it for rx and generate an ACK. ackState =
    //               s_new
    //New?        -> Store the src, dest, and count, set flag on it. swap it to
    //               data_msg. dataState = s_new

    //Type == Ack
    //duplicate ack?  -> return it. no change
    //No matching data record? -> return it. no state change.
    //Matching data,uncleared -> update the route info, swap it to ack_msg.
    //                 ackState = s_new. clear matching data flag.
    //for me?       -> post task to indicate was-acked. swap to
    //                 ack_msg. ackstate = s_new
    return msg;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
    //TODO: update rules for isDataFrame and isAckFrame
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
