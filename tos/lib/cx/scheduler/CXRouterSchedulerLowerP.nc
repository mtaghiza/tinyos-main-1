module CXRouterSchedulerLowerP {
  uses interface CXRequestQueue;
  provides interface CXRequestQueue as SlaveCXRQ;
  provides interface CXRequestQueue as MasterCXRQ;
  uses interface Get<bool> as GetSlaveMode;

  uses interface SplitControl;
  provides interface SplitControl as SlaveSplitControl;
  provides interface SplitControl as MasterSplitControl;
} implementation {
  command error_t SlaveSplitControl.start(){
    return call SplitControl.start();
  }
  command error_t MasterSplitControl.start(){
    return call SplitControl.start();
  }

  command error_t SlaveSplitControl.stop(){
    return call SplitControl.stop();
  }
  command error_t MasterSplitControl.stop(){
    return call SplitControl.stop();
  }

  event void SplitControl.startDone(error_t error){
    signal MasterSplitControl.startDone(error);
    signal SlaveSplitControl.startDone(error);
  }
  event void SplitControl.stopDone(error_t error){
    signal MasterSplitControl.stopDone(error);
    signal SlaveSplitControl.stopDone(error);
  }

  command uint32_t MasterCXRQ.nextFrame(bool isTX){
    return call CXRequestQueue.nextFrame(isTX);
  }
  command error_t MasterCXRQ.requestReceive(uint8_t layerCount,
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call CXRequestQueue.requestReceive(layerCount, baseFrame,
      frameOffset, useMicro, microRef, duration, md, msg);
  }

  command error_t MasterCXRQ.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    return call CXRequestQueue.requestSend(layerCount, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  command error_t MasterCXRQ.requestSleep(uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset){
    return call CXRequestQueue.requestSleep(layerCount, baseFrame,
      frameOffset);
  }
  command error_t MasterCXRQ.requestWakeup(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset,
      uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call CXRequestQueue.requestWakeup(layerCount, baseFrame,
      frameOffset, refFrame, refTime, correction);
  }

  command uint32_t SlaveCXRQ.nextFrame(bool isTX){
    return call CXRequestQueue.nextFrame(isTX);
  }
  command error_t SlaveCXRQ.requestReceive(uint8_t layerCount,
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call CXRequestQueue.requestReceive(layerCount, baseFrame,
      frameOffset, useMicro, microRef, duration, md, msg);
  }

  command error_t SlaveCXRQ.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    return call CXRequestQueue.requestSend(layerCount, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  command error_t SlaveCXRQ.requestSleep(uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset){
    return call CXRequestQueue.requestSleep(layerCount, baseFrame,
      frameOffset);
  }
  command error_t SlaveCXRQ.requestWakeup(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset,
      uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call CXRequestQueue.requestWakeup(layerCount, baseFrame,
      frameOffset, refFrame, refTime, correction);
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (call GetSlaveMode.get()){
      signal SlaveCXRQ.receiveHandled(error, layerCount - 1, atFrame,
        reqFrame, didReceive, microRef, t32kRef, md, msg);
    } else {
      signal MasterCXRQ.receiveHandled(error, layerCount - 1, atFrame,
        reqFrame, didReceive, microRef, t32kRef, md, msg);
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (call GetSlaveMode.get()){
      signal SlaveCXRQ.sendHandled(error, layerCount - 1, atFrame,
        reqFrame, microRef, t32kRef, md, msg);
    } else {
      signal MasterCXRQ.sendHandled(error, layerCount - 1, atFrame,
        reqFrame, microRef, t32kRef, md, msg);
    }
  }

  event void CXRequestQueue.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (call GetSlaveMode.get()){
      signal SlaveCXRQ.sleepHandled(error, layerCount - 1, atFrame,
        reqFrame);
    } else {
      signal MasterCXRQ.sleepHandled(error, layerCount - 1, atFrame,
        reqFrame);
    }
  }

  event void CXRequestQueue.wakeupHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    if (call GetSlaveMode.get()){
      signal SlaveCXRQ.wakeupHandled(error, layerCount - 1, atFrame,
        reqFrame);
    } else {
      signal MasterCXRQ.wakeupHandled(error, layerCount - 1, atFrame,
        reqFrame);
    }
  }

}
