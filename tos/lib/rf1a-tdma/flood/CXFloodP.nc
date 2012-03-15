
 #include "Rf1a.h"
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
    S_TX_WAIT = 0x01,
  };
  
  uint8_t state;
  SET_STATE_DEF

  uint16_t framesPerSlot;
  uint16_t activeFrames;
  uint16_t maxRetransmit;

  command error_t Send.send(message_t* msg, uint8_t len){
    TMP_STATE;
    CACHE_STATE;
    if (CHECK_STATE(S_IDLE)){
      atomic{
        tx_msg = msg;
        tx_len = len;
        SET_STATE(S_TX_WAIT, S_ERROR_1);
      }
    } else {
      return EBUSY;
    }
  }
  
  command error_t Send.cancel(message_t* msg){
    TMP_STATE;
    CACHE_STATE;
    if (CHECK_STATE(S_TX_WAIT)){
      SET_STATE(S_IDLE, S_ERROR_2);
      return SUCCESS;
    } else {
      return FAIL;
    }
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    return RF1A_OM_RX;
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    return FALSE;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
    framesPerSlot = framesPerSlot_;
    activeFrames  = activeFrames_;
    maxRetransmit = maxRetransmit_;
  }

  async event void CXTDMA.frameStarted(uint32_t startTime){ }
  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum){
    return msg;
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){}

  command void* Send.getPayload(message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength(){ return call LayerPacket.maxPayloadLength(); }

}
