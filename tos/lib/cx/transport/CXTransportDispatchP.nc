
 #include "CXTransport.h"
 #include "CXScheduler.h"
module CXTransportDispatchP {
  provides interface CXRequestQueue[uint8_t tp];
  uses interface CXRequestQueue as SubCXRQ;

  provides interface SplitControl;
  provides interface SplitControl as SubProtocolSplitControl[uint8_t tp];
  uses interface SplitControl as SubSplitControl;

  uses interface CXTransportPacket;
  uses interface CXPacketMetadata;

  uses interface RequestPending[uint8_t tp];
} implementation {
  //splitcontrol:
  // - commands and events should be passed through
  // - at SubSplitControl.startDone, notify CXRequestQueue clients
  //   that we're up 

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }
  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    signal SubProtocolSplitControl.startDone[CX_TP_FLOOD_BURST](error);
    signal SubProtocolSplitControl.startDone[CX_TP_RR_BURST](error);
    
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SubProtocolSplitControl.stopDone[CX_TP_FLOOD_BURST](error);
    signal SubProtocolSplitControl.stopDone[CX_TP_RR_BURST](error);
    signal SplitControl.stopDone(error);
  }

  //CXRequestQueue: 
  // - pass them on down
  
  command uint32_t CXRequestQueue.nextFrame[uint8_t tp](bool isTX){
    return call SubCXRQ.nextFrame(isTX);
  }

  command error_t CXRequestQueue.requestReceive[uint8_t tp](uint8_t layerCount,
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call SubCXRQ.requestReceive(layerCount, baseFrame, frameOffset,
      useMicro, microRef, duration, md, msg);
  }

  command error_t CXRequestQueue.requestSend[uint8_t tp](
      uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    call CXTransportPacket.setProtocol(msg, tp);
    return call SubCXRQ.requestSend(layerCount, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  command error_t CXRequestQueue.requestSleep[uint8_t tp](uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount, baseFrame,
      frameOffset);
  }

  command error_t CXRequestQueue.requestWakeup[uint8_t tp](uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset,
      uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call SubCXRQ.requestWakeup(layerCount, baseFrame,
      frameOffset, refFrame, refTime, correction);
  }
  
  uint32_t lastRXFrame = INVALID_FRAME;
  uint8_t nextRX = CX_TP_FLOOD_BURST;

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    uint8_t signalTp; 
    if (didReceive){
      if (lastRXFrame == atFrame){
        printf("! RX twice in same frame\r\n");
        return;
      }
      lastRXFrame = atFrame;
      signalTp = call CXTransportPacket.getProtocol(msg);
      printf("rx %x\r\n", signalTp);
      //scheduled send gets received by flood: otherwise, we have to
      //have scheduledTXP polling for receives as well.
      if (signalTp == CX_TP_SCHEDULED){
        signalTp = CX_TP_FLOOD_BURST;
        printf("s->f %x\r\n", signalTp);
      }
    } else {
      uint8_t i;
      signalTp = nextRX;
      for (i = 0; i < NUM_RX_TRANSPORT_PROTOCOLS; i++){
        if (! call RequestPending.requestPending[signalTp](reqFrame)){
          signalTp = (1+signalTp)%NUM_RX_TRANSPORT_PROTOCOLS;
        } else {
          break;
        }
      }
    }

//    printf("rxh %x to %x (%x)\r\n", didReceive, signalTp, nextRX);
    if (call RequestPending.requestPending[signalTp](reqFrame)){
      signal CXRequestQueue.receiveHandled[signalTp](error,
        layerCount,
        atFrame, reqFrame, 
        didReceive,
        microRef, t32kRef,
        md, msg);
    }else{
      printf("!no pending rx req to %x\r\n", signalTp);
    }
    nextRX = (signalTp + 1)%NUM_RX_TRANSPORT_PROTOCOLS;
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (call CXPacketMetadata.getRequestedFrame(msg) != INVALID_FRAME){
      signal CXRequestQueue.sendHandled[CX_TP_SCHEDULED](
        error,
        layerCount,
        atFrame, reqFrame, microRef, t32kRef, md, msg);
    } else {
      signal CXRequestQueue.sendHandled[call CXTransportPacket.getProtocol(msg)](
        error,
        layerCount,
        atFrame, reqFrame, microRef, t32kRef, md, msg);
    }
  }

  //no good way to dispatch these at the moment. oh well.
  event void SubCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){}

  event void SubCXRQ.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){}

  command error_t SubProtocolSplitControl.start[uint8_t tp](){ return FAIL;}
  command error_t SubProtocolSplitControl.stop[uint8_t tp](){ return FAIL;}

  default event void CXRequestQueue.sendHandled[uint8_t tp](error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    printf("!default t.sh: %x\r\n", tp);
  }

  default event void CXRequestQueue.receiveHandled[uint8_t tp](error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    printf("!default t.rh: %x\r\n", tp);
  }

  default event void SubProtocolSplitControl.startDone[uint8_t tp](error_t error){
  }
  default event void SubProtocolSplitControl.stopDone[uint8_t tp](error_t error){
  }

  default command bool RequestPending.requestPending[uint8_t tp](uint32_t frame){
    printf("!default RP to %x\r\n", tp);
    return FALSE;
  }
}
