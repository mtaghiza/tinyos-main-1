 #include "CXTDMADispatchDebug.h"
 #include "FECDebug.h"

module CXTDMADispatchP{
  provides interface CXTDMA[uint8_t clientId];

  uses interface CXTDMA as SubCXTDMA;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  provides interface TaskResource[uint8_t np];
} implementation {

  enum {
    INVALID_OWNER = 0xFF,
  };

  uint16_t lastFrame;
  uint8_t owner = INVALID_OWNER;

  command error_t TaskResource.immediateRequest[uint8_t np](){
    if (owner == INVALID_OWNER){
      owner = np;
      return SUCCESS;
    }else{
      return FAIL;
    }
  }

  command error_t TaskResource.release[uint8_t np](){
    if (owner == np){
      owner = INVALID_OWNER;
      return SUCCESS;
    }
    return FAIL;
  }

  command bool TaskResource.isOwner[uint8_t np](){
    return np == owner;
  }

  bool isClaimed(){
    return owner != INVALID_OWNER;
  }

  event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    lastFrame = frameNum;
    if ( isClaimed() ){
      return signal CXTDMA.frameType[owner](frameNum);
    } else {
      rf1a_offmode_t ret;
      ret = signal CXTDMA.frameType[CX_NP_FLOOD](frameNum);
      if ( ! isClaimed()){
        ret = signal CXTDMA.frameType[CX_NP_SCOPEDFLOOD](frameNum);
      }
      if ( ! isClaimed()){
        ret = RF1A_OM_RX;
      }
      return ret;
    }
  }

  event bool SubCXTDMA.getPacket(message_t** msg,
      uint16_t frameNum){ 
    if ( isClaimed() ){
      return signal CXTDMA.getPacket[owner](msg,
        frameNum);
    } else {
      return FALSE;
    }
  }

  event void SubCXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (isClaimed()){
      signal CXTDMA.sendDone[owner](msg, len, frameNum, error);
    } else {
      printf("!Unclaimed SD\r\n");
    }
  }

  message_t* dispMsg;
  task void displayPacket(){
    printf(" CX d: %x sn: %x count: %x sched: %x of: %x ts: %lx np: %x tp: %x type: %x\r\n", 
      call CXPacket.destination(dispMsg),
      call CXPacket.sn(dispMsg),
      call CXPacket.count(dispMsg),
      call CXPacket.getScheduleNum(dispMsg),
      call CXPacket.getOriginalFrameNum(dispMsg),
      call CXPacket.getTimestamp(dispMsg),
      call CXPacket.getNetworkProtocol(dispMsg),
      call CXPacket.getTransportProtocol(dispMsg),
      call CXPacket.type(dispMsg));
   }

  event message_t* SubCXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    printf_TMP("#D %x\r\n",
      call CXPacket.getNetworkProtocol(msg) & ~CX_NP_PREROUTED);
    return signal CXTDMA.receive[ call CXPacket.getNetworkProtocol(msg) & ~CX_NP_PREROUTED](msg, len, frameNum, timestamp);
  }

  default event rf1a_offmode_t CXTDMA.frameType[uint8_t NetworkProtocol](uint16_t frameNum){
    return RF1A_OM_RX;
  }
  default event bool CXTDMA.getPacket[uint8_t NetworkProtocol](message_t** msg, 
      uint16_t frameNum){ return FALSE;}
  default event void CXTDMA.sendDone[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){}

  default event message_t* CXTDMA.receive[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    printf("Unexpected RM %x: ", NetworkProtocol);
    return msg;
  }

}
