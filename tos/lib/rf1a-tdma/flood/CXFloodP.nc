
 #include "Rf1a.h"
 #include "CXFlood.h"
 #include "FDebug.h"
 #include "AODVDebug.h"
 #include "BreakfastDebug.h"
module CXFloodP{
  provides interface Send[am_id_t t];
  provides interface Receive[am_id_t t];
  provides interface Receive as Snoop[am_id_t t];

  uses interface CXPacket;
  //Payload: body of CXPacket
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface Resource;
  
  uses interface CXRoutingTable;

} implementation {

  enum{
    ERROR_MASK = 0x80,
    S_ERROR_1 = 0x81,
    S_ERROR_2 = 0x82,
    S_ERROR_3 = 0x83,
    S_ERROR_4 = 0x84,
    S_ERROR_5 = 0x85,
    S_ERROR_6 = 0x86,
    S_ERROR_7 = 0x87,
    S_ERROR_8 = 0x88,
    S_ERROR_9 = 0x89,
    S_ERROR_a = 0x8a,
    S_ERROR_b = 0x8b,
    S_ERROR_c = 0x8c,
    S_ERROR_d = 0x8d,
    S_ERROR_e = 0x8e,
    S_ERROR_f = 0x8f,

    S_IDLE = 0x00,
    S_FWD  = 0x01,
  };

  //provided by Send
  message_t* tx_msg;
  uint8_t tx_len; 

  bool txPending;
  bool txSent;
  uint16_t txLeft;

  am_addr_t lastSrc = 0x00;
  uint8_t lastSn;
  uint8_t lastDepth;
  
  uint8_t state;

  uint16_t framesPerSlot;
  uint16_t curFrame;
  uint16_t activeFrames;

  message_t fwd_msg_internal;
  message_t* fwd_msg = &fwd_msg_internal;
  uint8_t fwd_len;
  
  bool rxOutstanding;

  //distinguish between tx_msg and fwd_msg
  bool isOrigin;

  void setState(uint8_t s){
    printf_F_STATE("(%x->%x)\r\n", state, s);
    state = s;
  }

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
    atomic{
      if (!txPending){
        tx_msg = msg;
        tx_len = len + sizeof(cx_header_t) ;
//        printf("flood %u -> %u\r\n", len, tx_len);
        txPending = TRUE;
        call CXPacket.init(msg);
        call CXPacket.setType(msg, t);
        //preserve pre-routed flag
        call CXPacket.setRoutingMethod(msg, 
          (call CXPacket.getRoutingMethod(msg) & CX_RM_PREROUTED) | CX_RM_FLOOD);
        printf_F_SCHED("fs.s %p %u\r\n", msg, call CXPacket.count(msg));
        return SUCCESS;
      }else{
        return EBUSY;
      }
    }
  }
  
  //TODO: yeah, we're going to have to implement this. should be just
  //clear txPending flag and go to IDLE?
  command error_t Send.cancel[am_id_t t](message_t* msg){
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    //should be an isOrigin command provided by some other component
    //(RootC / NonRootC? For AODV, will want to send as many packets
    //in a frame as it can.)

    printf_F_SCHED("f.ft %u", frameNum);
    if (txPending && (call TDMARoutingSchedule.isOrigin(frameNum))){
      printf_F_SCHED("o");
      if (SUCCESS == call Resource.immediateRequest()){
        printf_F_SCHED(" tx\r\n");
        txLeft = call TDMARoutingSchedule.maxRetransmit();
        lastSn = call CXPacket.sn(tx_msg);
        lastSrc = TOS_NODE_ID;
        txSent = TRUE;
        isOrigin = TRUE;
        setState(S_FWD);
        return RF1A_OM_FSTXON;
      } else {
        printf_F_SCHED("! rx\r\n");
        return RF1A_OM_RX;
      }
    }else{
      printf_F_SCHED("n");
    }

    if (txLeft){
      printf_F_SCHED("f\r\n");
      return RF1A_OM_FSTXON;
    } else {
      printf_F_SCHED("r\r\n");
      return RF1A_OM_RX;
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    printf_F_GP("f.gp");
    if (isOrigin){
      printf_F_GP("o\r\n");
      F_GPO_SET_PIN;
      *msg = tx_msg;
      *len = tx_len;
      F_GPO_CLEAR_PIN;
      return TRUE;
    } else {
      F_GPF_SET_PIN;
      printf_F_GP("f\r\n");
      *msg = fwd_msg;
      *len = fwd_len;
      F_GPF_CLEAR_PIN;
      return TRUE;
    }
  }

  task void txSuccessTask(){
    atomic {
      txPending = FALSE;
      txSent = FALSE;
    }
    signal Send.sendDone[call CXPacket.type(tx_msg)](tx_msg, SUCCESS);
  }

  task void reportReceive(){
    atomic{
      if (rxOutstanding){
        rxOutstanding = FALSE;
        //TODO: should we update the routing table? or should we
        //reserve that space for scoped floods, which may request
        //future routing explicitly?
        if ( (call CXPacket.destination(fwd_msg) == TOS_NODE_ID) ||
            (call CXPacket.destination(fwd_msg) == AM_BROADCAST_ADDR)){
          fwd_msg = signal Receive.receive[call CXPacket.type(fwd_msg)](
            fwd_msg, 
            call LayerPacket.getPayload(fwd_msg, fwd_len- sizeof(cx_header_t)),
            fwd_len - sizeof(cx_header_t));
        }else {
          fwd_msg = signal Snoop.receive[call CXPacket.type(fwd_msg)](
            fwd_msg, 
            call LayerPacket.getPayload(fwd_msg, fwd_len- sizeof(cx_header_t)),
            fwd_len - sizeof(cx_header_t));
        }
      }
    }
  }
  void checkAndCleanup(){
    if (txLeft == 0){
      setState(S_IDLE);
      isOrigin = FALSE;
      call Resource.release();
      if (txSent){
        post txSuccessTask();
      } else {
        post reportReceive();
      }
    }
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (error != SUCCESS){
      printf("CXFloodP sd!\r\n");
      setState(S_ERROR_1);
    }
    if (txLeft > 0){
      txLeft --;
    }else{
      printf("CXFloodP sent extra?\r\n");
    }
//    printf("sd %p %u %lu \r\n", msg, call CXPacket.count(msg), call CXPacket.getTimestamp(msg));
    checkAndCleanup();
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    am_addr_t thisSrc = call CXPacket.source(msg);
    uint8_t thisSn = call CXPacket.sn(msg);
    printf_F_RX("rx ");
    if (state == S_IDLE){
      //new packet
      if (! ((thisSn == lastSn) && (thisSrc == lastSrc))){
        call CXRoutingTable.update(thisSrc, TOS_NODE_ID, 
          call CXPacket.count(msg));
        printf_F_RX("n");

        //check for routed flag: ignore it if the routed flag is
        //set, but we are not on the path.
        if (call CXPacket.getRoutingMethod(msg) & CX_RM_PREROUTED){
          bool isBetween;
          printf_F_RX("p");
          if ((SUCCESS != call CXRoutingTable.isBetween(thisSrc, 
              call CXPacket.destination(msg), &isBetween)) || !isBetween ){
            printf_F_RX("~b\r\n");
            return msg;
          }else{
            printf_F_RX("b");
          }
        }

        if (SUCCESS == call Resource.immediateRequest()){
          message_t* ret = fwd_msg;
          printf_F_RX("f\r\n");
          lastSn = thisSn;
          lastSrc = thisSrc;
          lastDepth = call CXPacket.count(msg);
          txLeft = call TDMARoutingSchedule.maxRetransmit();
          fwd_msg = msg;
          fwd_len = len;
          rxOutstanding = TRUE;
          setState(S_FWD);
          //to handle the case where retx = 0
          checkAndCleanup();
          return ret;

        //couldn't get the resource, ignore this packet.
        } else {
          printf_F_RX("!R\r\n");
          return msg;
        }
      //duplicate, ignore
      } else {
        printf_F_RX("d\r\n");
        return msg;
      }

    //busy forwarding, ignore it.
    } else {
      printf_F_RX("b\r\n");
      return msg;
    }
  }

  event void Resource.granted(){}

  command void* Send.getPayload[am_id_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[am_id_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[am_id_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}
  default event message_t* Snoop.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}
}
