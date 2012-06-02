 #include "CXTDMADispatchDebug.h"
 #include "FECDebug.h"

module CXTDMADispatchP{
  provides interface CXTDMA[uint8_t clientId];

  uses interface CXTDMA as SubCXTDMA;
  uses interface ArbiterInfo;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  provides interface Resource[uint8_t NetworkProtocol];
  uses interface Resource as SubResource[uint8_t NetworkProtocol];
} implementation {
  uint16_t lastFrame;

  async command error_t Resource.request[uint8_t NetworkProtocol](){
    #ifdef DEBUG_TESTBED_RESOURCE
    printf_TESTBED_RESOURCE("R.q %x %u\r\n", NetworkProtocol, lastFrame);
    #endif
    return  call SubResource.request[NetworkProtocol]();
  }
  async command error_t Resource.immediateRequest[uint8_t NetworkProtocol](){
    #ifdef DEBUG_TESTBED_RESOURCE
    printf_TESTBED_RESOURCE("R.ir %x %u\r\n", NetworkProtocol, lastFrame);
    #endif
    return call SubResource.immediateRequest[NetworkProtocol]();
  }
  event void SubResource.granted[uint8_t NetworkProtocol](){
    #ifdef DEBUG_TESTBED_RESOURCE
    printf_TESTBED_RESOURCE("R.g %x %u\r\n", NetworkProtocol, lastFrame);
    #endif
    signal Resource.granted[NetworkProtocol]();
  }
  async command error_t Resource.release[uint8_t NetworkProtocol](){
    #ifdef DEBUG_TESTBED_RESOURCE
    printf_TESTBED_RESOURCE("R.r %x %u\r\n", NetworkProtocol, lastFrame);
    #endif
    return call SubResource.release[NetworkProtocol]();
  }
  async command bool Resource.isOwner[uint8_t NetworkProtocol](){
    #ifdef DEBUG_TESTBED_RESOURCE
    printf_TESTBED_RESOURCE("R.o %x %u\r\n", NetworkProtocol, lastFrame);
    #endif
    return call SubResource.isOwner[NetworkProtocol]();
  }

  async event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    lastFrame = frameNum;
    if ( call ArbiterInfo.inUse()){
//      printf_TESTBED_RESOURCE("RH %x\r\n", 
//        call ArbiterInfo.userId());
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

  #if SW_TOPO == 1
    #warning Enforcing topology in software
    #if TOPOLOGY == 1
    //line topo
    uint8_t depthFrom0[5] = {0, 1, 2, 3, 4};
    uint8_t depthFrom1[5] = {1, 0, 1, 2, 3};
    uint8_t depthFrom2[5] = {2, 1, 0, 1, 2};
    uint8_t depthFrom3[5] = {3, 2, 1, 0, 1};
    uint8_t depthFrom4[5] = {4, 3, 2, 1, 0};
    #elif TOPOLOGY == 2
    //2x2 topo
    uint8_t depthFrom0[5] = {0, 1, 1, 2, 2};
    uint8_t depthFrom1[5] = {1, 0, 1, 1, 1};
    uint8_t depthFrom2[5] = {1, 1, 0, 1, 1};
    uint8_t depthFrom3[5] = {2, 1, 1, 0, 1};
    uint8_t depthFrom4[5] = {2, 1, 1, 1, 0};
    #else 
    #error Unknown TOPOLOGY
    #endif
    uint8_t* depthFrom(){
      switch(TOS_NODE_ID){
        case 0:
          return depthFrom0;
        case 1:
          return depthFrom1;
        case 2:
          return depthFrom2;
        case 3:
          return depthFrom3;
        case 4:
          return depthFrom4;
        default:
          printf("unknown TOS_NODE_ID %u\r\n", TOS_NODE_ID);
          return depthFrom0;
      }
    }
  #endif

  bool deliverMsg(message_t* msg){
    bool SRResult = TRUE;
    bool topoResult = TRUE;
    #ifdef DISCONNECTED_SR
    SRResult = (call CXPacketMetadata.getSymbolRate(msg) < DISCONNECTED_SR);
//    printf("sr: %u dsr: %u\r\n", 
//      call CXPacketMetadata.getSymbolRate(msg), 
//      DISCONNECTED_SR);
    #endif
    #if SW_TOPO == 1
      //the window where we receive packets is from 
      // count == depth -> count == depth + retx + 1 
      //
      // because after we finish retransmitting, we overhear the nodes
      // 1 hop away from us retransmitting
      topoResult = ( call CXPacketMetadata.getReceivedCount(msg) >=
      depthFrom()[call CXPacket.source(msg)] 
        && call CXPacketMetadata.getReceivedCount(msg) <=
        depthFrom()[call CXPacket.source(msg)] + TDMA_MAX_RETRANSMIT + 1 );
    #endif
    return SRResult && topoResult;
    
  }

  async event message_t* SubCXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
//    uint8_t i;
//    printf("RM %x: ", call CXPacket.getNetworkProtocol(msg));
//    for (i =0 ; i< TOSH_DATA_LENGTH + sizeof(message_header_t); i++){
//      printf("%02X ", ((uint8_t*)msg)[i]);
//    }
//    printf("\r\n");

    if (deliverMsg(msg)){
      #if SW_TOPO == 1
      printf_SW_TOPO("KEEP %u (%u) %u \r\n", 
        call CXPacket.source(msg), 
        depthFrom()[call CXPacket.source(msg)], 
        call CXPacketMetadata.getReceivedCount(msg));
      #endif
      return signal CXTDMA.receive[ call CXPacket.getNetworkProtocol(msg) & ~CX_RM_PREROUTED](msg, len, frameNum, timestamp);
    } else {
      #if SW_TOPO == 1
      printf_SW_TOPO("DROP %u (%u) %u \r\n", 
        call CXPacket.source(msg), 
        depthFrom()[call CXPacket.source(msg)], 
        call CXPacketMetadata.getReceivedCount(msg));
      #endif
      return msg;
    }
  }
  default event void Resource.granted[uint8_t NetworkProtocol](){
  }
  default async event rf1a_offmode_t CXTDMA.frameType[uint8_t NetworkProtocol](uint16_t frameNum){
    return RF1A_OM_RX;
  }
  default async event bool CXTDMA.getPacket[uint8_t NetworkProtocol](message_t** msg, uint8_t* len,
      uint16_t frameNum){ return FALSE;}
  default async event void CXTDMA.sendDone[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){}

  default async event message_t* CXTDMA.receive[uint8_t NetworkProtocol](message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    printf("Unexpected RM %x: ", NetworkProtocol);
    return msg;
  }

}
