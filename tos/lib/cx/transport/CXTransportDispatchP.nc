module CXTransportDispatchP {
  provides interface CXRequestQueue[uint8_t tp];
  uses interface CXRequestQueue as SubCXRQ;

  provides interface SplitControl;
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
    //TODO: notify layers above that we're on
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    //TODO: notify layers above that we're off
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

  }

  command error_t CXRequestQueue.requestSend[uint8_t tp](
      uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){
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

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: see logic below
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: check protocol, signal appropriately
  }
  

  //no good way to dispatch these at the moment. oh well.
  event void SubCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){}

  event void SubCXRQ.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){}


  //SubCXRQ:
  // - txHandled: dispatch based on transport protocol
  // - rxHandled, SUCCESS
  //   - didReceive = TRUE:  dispatch based on tp, set next to
  //     (tp + 1 )% tp_range
  //   - didReceive = FALSE: set next to (next+1)%tp_range
  // - rxHandled, EBUSY
  //   - dispatch to next, set next to (next+1)%tp_range
}
