module CXTDMADispatchP{
  provides interface CXTDMA[uint8_t clientId];

  uses interface CXTDMA as SubCXTDMA;
  uses interface ArbiterInfo;
  uses interface CXPacket;
} implementation {

  async event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    if ( call ArbiterInfo.inUse()){
      return signal CXTDMA.frameType[call ArbiterInfo.userId()](frameNum);
    } else {
      rf1a_offmode_t ret;
      ret = signal CXTDMA.frameType[CX_RM_FLOOD](frameNum);
      if ( ! call ArbiterInfo.inUse()){
        ret = signal CXTDMA.frameType[CX_RM_SCOPEDFLOOD](frameNum);
      }
      if ( ! call ArbiterInfo.inUse()){
        ret = signal CXTDMA.frameType[CX_RM_AODV](frameNum);
      }
      if ( ! call ArbiterInfo.inUse()){
        ret = RF1A_OM_RX;
      }
      return ret;
    }
  }

  async event bool SubCXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){ 
    if ( call ArbiterInfo.inUse()){
      return signal CXTDMA.getPacket[call ArbiterInfo.userId()](msg,
        len, frameNum);
    } else {
      return FALSE;
    }
  }

  async event void SubCXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (call ArbiterInfo.inUse()){
      signal CXTDMA.sendDone[call ArbiterInfo.userId()](msg, len, frameNum, error);
    } else {
      //TODO: handle error here.
    }
  }

  async event message_t* SubCXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    return signal CXTDMA.receive[ call CXPacket.getRoutingMethod(msg) & ~CX_RM_PREROUTED](msg, len, frameNum, timestamp);
  }

  default async event rf1a_offmode_t CXTDMA.frameType[uint8_t routingMethod](uint16_t frameNum){
    return RF1A_OM_RX;
  }
  default async event bool CXTDMA.getPacket[uint8_t routingMethod](message_t** msg, uint8_t* len,
      uint16_t frameNum){ return FALSE;}
  default async event void CXTDMA.sendDone[uint8_t routingMethod](message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){}
  default async event message_t* CXTDMA.receive[uint8_t routingMethod](message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    return msg;
  }

}
