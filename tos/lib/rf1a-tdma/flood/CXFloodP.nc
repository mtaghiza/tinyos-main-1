
 #include "Rf1a.h"
 #include "CXFlood.h"
module CXFloodP{
  provides interface Send[am_id_t t];
  provides interface Receive[am_id_t t];

  uses interface CXPacket;
  //Payload: body of CXPacket
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMAScheduler;
} implementation {
  message_t* tx_msg;
  uint8_t tx_len; 

  am_addr_t lastSrc = 0x00;
  uint8_t lastSn;

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
    S_TX_NEXT = 0x02,
    S_TX = 0x03,
  };

  bool txPending;
  bool txSent;
  uint16_t txLeft;
  uint16_t thisStart;
  
  uint8_t state;
  SET_STATE_DEF

  uint16_t framesPerSlot;
  uint16_t curFrame;
  uint16_t activeFrames;

  //initialize this to 1: when we receive the very first schedule, we
  //get notified of its reception before we get the new schedule. by
  //setting this to 1 initially, we can get faster startup across the
  //network.
  uint16_t maxRetransmit = 1;

  uint16_t myStart;

  message_t* fwd_msg;
  uint8_t fwd_len;
  
  bool rxOutstanding;
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
//    printf("Somebody called send\r\n");
    atomic{
      if (!txPending){
        tx_msg = msg;
        tx_len = len + sizeof(cx_header_t) ;
        //TODO: where do we account for 15.4 header len?
        txPending = TRUE;
        call CXPacket.init(msg);
        call CXPacket.setType(msg, t);
        call CXPacket.setRoutingMethod(msg, CX_RM_FLOOD);

        return SUCCESS;
      }else{
        return EBUSY;
      }
    }
  }
  
  command error_t Send.cancel[am_id_t t](message_t* msg){
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    //TODO: might want to make this a little more flexible: for
    //instance, root is going to want to claim slot 0 for the
    //schedule, but may want another slot for its own data.
    printf("ft %x %u %u %u:", txPending, frameNum, myStart, maxRetransmit);
    if (txPending 
        && (frameNum >= myStart) 
        && (frameNum < (myStart + maxRetransmit))){
      printf("txo\r\n");
      return RF1A_OM_FSTXON;
    } else if (frameNum < (thisStart + txLeft)){
      printf("txf\r\n");
      return RF1A_OM_FSTXON;
    } else {
      printf("r\r\n");
      return RF1A_OM_RX;
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    GP_SET_PIN;
    if (txPending 
        && (frameNum >= myStart) 
        && (frameNum < (myStart + maxRetransmit))){
      GP_CLEAR_PIN;
      *msg = tx_msg;
      *len = tx_len;
      return TRUE;
    } else if (txLeft){
      *msg = fwd_msg;
      *len = fwd_len;
//      GP_CLEAR_PIN;
//      GP_SET_PIN;
      GP_CLEAR_PIN;
      return TRUE;
    }
//    printf("c");
//    GP_SET_PIN;
//    GP_CLEAR_PIN;
//    GP_SET_PIN;
//    GP_CLEAR_PIN;
//    GP_SET_PIN;
    GP_CLEAR_PIN;
    return FALSE;
  }

  task void txSuccessTask(){
    txPending = FALSE;
    signal Send.sendDone[call CXPacket.type(tx_msg)](tx_msg, SUCCESS);
  }

  task void reportReceive(){
    atomic{
      if (rxOutstanding){
        rxOutstanding = FALSE;
        rx_msg = signal Receive.receive[call CXPacket.type(rx_msg)](rx_msg, 
          call LayerPacket.getPayload(rx_msg, rx_len- sizeof(cx_header_t)),
          rx_len - sizeof(cx_header_t));
      }
    }
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (error != SUCCESS){
      printf("sd!\r\n");
      SET_ESTATE(S_ERROR_1);
    }
    lastSrc = call CXPacket.source(msg);
    lastSn = call CXPacket.sn(msg);
    if (txLeft > 0){
      txLeft --;
    }else{
      printf("sent extra?\r\n");
    }
    if (txLeft == 0){
      thisStart = 0;
      if (txSent){
        printf("Odone\r\n");
        post txSuccessTask();
      } else {
        printf("Rdone\r\n");
        post reportReceive();
      }
    }
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum){
    am_addr_t thisSrc = call CXPacket.source(msg);
    uint8_t thisSn = call CXPacket.sn(msg);
//    printf("rx %p %x %u\r\n", msg, thisSrc, thisSn);
    if (! ((thisSn == lastSn) && (thisSrc == lastSrc))){
      lastSn = thisSn;
      lastSrc = thisSrc;
      txLeft = maxRetransmit;
      thisStart = frameNum + 1;
      fwd_msg = msg;
      fwd_len = len;
      if (! rxOutstanding){
        message_t* swap = rx_msg;
//        printf("rx.\r\n");
        rxOutstanding = TRUE;
        rx_msg = msg;
        rx_len = len;
        return swap;
      } else {
//        printf("rx!\r\n");
        SET_ESTATE(S_ERROR_2);
        return msg;
      }
    } else {
      printf("rxd\r\n");
      return msg;
    }
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
    atomic{
      framesPerSlot = framesPerSlot_;
      activeFrames  = activeFrames_;
      maxRetransmit = maxRetransmit_;
      myStart = (framesPerSlot * TOS_NODE_ID);
    }
//    printf("sched: %u %u %u %u\r\n", framesPerSlot, activeFrames,
//      maxRetransmit, myStart);
  }

  async event void CXTDMA.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ 
    if (txPending && (frameNum == myStart)){
      thisStart = frameNum;
      txLeft = maxRetransmit;
      txSent = TRUE;
    }
  }


  command void* Send.getPayload[am_id_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[am_id_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[am_id_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}

}
