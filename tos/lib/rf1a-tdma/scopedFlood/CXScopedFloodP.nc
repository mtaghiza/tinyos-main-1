
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

  command error_t Send.send[am_id_t t](message_t* msg, uint8_t len){
//    printf("Somebody called send\r\n");
//    atomic{
//      if (!txPending){
//        tx_msg = msg;
//        tx_len = len + sizeof(cx_header_t) ;
//        txPending = TRUE;
//        call CXPacket.init(msg);
//        call CXPacket.setType(msg, t);
//        call CXPacket.setRoutingMethod(msg, CX_RM_SCOPEDFLOOD);
//
//        return SUCCESS;
//      }else{
//        return EBUSY;
//      }
//    }
    return FAIL;
  }
  
  command error_t Send.cancel[am_id_t t](message_t* msg){
    return FAIL;
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    return RF1A_OM_RX;
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
   return FALSE;
  }

  async event void CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    return msg;
  }

  event void TDMAScheduler.scheduleReceived(uint16_t activeFrames_, 
      uint16_t inactiveFrames, uint16_t framesPerSlot_, 
      uint16_t maxRetransmit_){
  }

  async event void CXTDMA.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ 
  }

  event void Resource.granted(){}

  command void* Send.getPayload[am_id_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[am_id_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[am_id_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[am_id_t t](message_t* msg, void* payload, uint8_t len){ return msg;}

}
