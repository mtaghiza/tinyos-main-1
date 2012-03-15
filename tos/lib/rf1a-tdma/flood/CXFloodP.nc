
 #include "Rf1a.h"
 #include "CXFlood.h"
module CXFloodP{
  provides interface Send;
  provides interface Receive;

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
  bool txSending;
  bool fwdPending;
  
  uint8_t state;
  SET_STATE_DEF

  uint16_t framesPerSlot;
  uint16_t curFrame;
  uint16_t activeFrames;
  uint16_t maxRetransmit;

  uint16_t myStart;
  uint16_t lastFwd;

  message_t* fwd_msg;
  uint8_t fwd_len;
  
  bool rxOutstanding;
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;

  command error_t Send.send(message_t* msg, uint8_t len){
    atomic{
      if (!txPending){
        tx_msg = msg;
        tx_len = len;
        txPending = TRUE;
        //TODO: prepare packet
        call CXPacket.init(msg);
        call CXPacket.setType(msg, CX_TYPE_FLOOD);

        return SUCCESS;
      }else{
        return EBUSY;
      }
    }
  }
  
  command error_t Send.cancel(message_t* msg){
    atomic{
      if (!txPending){
        return EINVAL;
      } else if ((curFrame >= myStart) || 
          (curFrame < (myStart + maxRetransmit))){
        //too late!
        return  FAIL;
      } else {
        //ok.
        txPending = FALSE;
        return SUCCESS;
      }
    }
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    if (txPending && (frameNum == myStart)){
      return RF1A_OM_FSTXON;
    } else if (fwdPending){
//      printf("ft %u: lf %u ", frameNum, lastFwd);
      if (frameNum <= lastFwd){
        return RF1A_OM_FSTXON;
      } else {
        //done forwarding, get ready for next packet.
        return RF1A_OM_RX;
      }
    } else {
      //not involved in forwarding or originating
      return RF1A_OM_RX;
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    if (fwdPending){
      *msg = fwd_msg;
      *len = fwd_len;
      return TRUE;
    } else if (txPending){
      txSending = TRUE;
      lastFwd = frameNum + maxRetransmit;
      *msg = tx_msg;
      *len = tx_len;
      return TRUE;
    } 
    return FALSE;
  }

  task void txSuccessTask(){
    signal Send.sendDone(tx_msg, SUCCESS);
  }

  task void reportReceive(){
    atomic{
      if (rxOutstanding){
        rxOutstanding = FALSE;
        rx_msg = signal Receive.receive(rx_msg, 
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

    if (txSending){
      printf("sdt\r\n");
      txSending = FALSE;
      fwdPending = TRUE;
      fwd_msg = tx_msg;
      fwd_len = tx_len;
    }

    if (frameNum == lastFwd){
      printf("sdd\r\n");
      fwdPending = FALSE;
      if (txPending){
        post txSuccessTask();
      } else {
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
      fwdPending = TRUE;
      lastFwd = frameNum + maxRetransmit;
      fwd_msg = msg;
      fwd_len = len;
      if (! rxOutstanding){
        message_t* swap = rx_msg;
        printf("rx.\r\n");
        rxOutstanding = TRUE;
        rx_msg = msg;
        rx_len = len;
        return swap;
      } else {
        printf("rx!\r\n");
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

  async event void CXTDMA.frameStarted(uint32_t startTime){ }


  command void* Send.getPayload(message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength(){ return call LayerPacket.maxPayloadLength(); }

}
