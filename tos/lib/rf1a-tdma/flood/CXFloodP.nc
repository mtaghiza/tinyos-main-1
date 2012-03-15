
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

  command error_t Send.send(message_t* msg, uint8_t len){
    //TODO: if we're not busy, store the params, set up header, and
    //      wait until our frame comes around.
    return FAIL;
  }
  
  command error_t Send.cancel(message_t* msg){
    //TODO: check for whether we've given this packet up yet. if not,
    //update state and return SUCCESS.
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    return RF1A_OM_RX;
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    return FALSE;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames, 
      uint16_t inactiveFrames, uint16_t framesPerSlot, 
      uint16_t maxRetransmit){}

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
