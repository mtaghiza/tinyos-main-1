
 #include "CXTransport.h"
 #include "CXScheduler.h"
module CXTransportDispatchP {
  provides interface CXRequestQueue[uint8_t tp];
  uses interface CXRequestQueue as SubCXRQ;

  provides interface SplitControl;
  provides interface SplitControl as SubProtocolSplitControl[uint8_t tp];
  uses interface SplitControl as SubSplitControl;

  uses interface CXTransportPacket;
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
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){
    call CXTransportPacket.setProtocol(msg, tp);
    return call SubCXRQ.requestSend(layerCount, baseFrame,
      frameOffset, useMicro, microRef, tsLoc, md, msg);
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
    if (lastRXFrame == atFrame){
      signalTp = nextRX;
    } else if (didReceive){
      signalTp = call CXTransportPacket.getProtocol(msg);
    } else {
      printf("! didReceive >1x for same frame\r\n");
      return;
    }

    lastRXFrame = atFrame;
    nextRX = (signalTp + 1)%NUM_TRANSPORT_PROTOCOLS;
    signal CXRequestQueue.receiveHandled[signalTp](error,
      layerCount,
      atFrame, reqFrame, 
      didReceive,
      microRef, t32kRef,
      md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.sendHandled[call CXTransportPacket.getProtocol(msg)](
      error,
      layerCount,
      atFrame, reqFrame, microRef, t32kRef, md, msg);
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
}
