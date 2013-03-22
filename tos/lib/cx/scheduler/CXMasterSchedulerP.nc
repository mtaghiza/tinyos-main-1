
 #include "CXScheduler.h"
module CXMasterSchedulerP{
  provides interface SplitControl;
  provides interface CXRequestQueue;
  
  uses interface SplitControl as SubSplitControl;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface Packet;
} implementation {
  message_t schedMsg_internal;
  message_t* schedMsg = &schedMsg_internal;
  cx_schedule_t* sched;

  uint32_t lastWakeup;
  uint32_t lastSleep;

  task void init(){
    uint32_t refFrame = call SubCXRQ.nextFrame(FALSE);
    error_t error; 
    //TODO: set up schedule
    error = call SubCXRQ.requestWakeup(0, refFrame, 1);
    if (SUCCESS == error){
      error = call SubCXRQ.requestSleep(0, refFrame, 1 + sched->cycleLen);
      if (SUCCESS == error){
        //cool. we'll request TX when we wake up.
      }else{
        printf("init.requestSleep: %x\r\n", error);
      }
    }else{
      printf("init.requestWakeup %x\r\n", error);
    }
  }

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    return 0;
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, 
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call SubCXRQ.requestReceive(layerCount + 1, baseFrame, frameOffset,
      useMicro, microRef, 
      duration, 
      md, msg);
  }

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal SubCXRQ.receiveHandled(error, layerCount - 1, atFrame, reqFrame,
      didReceive, microRef, t32kRef, md, msg);
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){

    call CXSchedulerPacket.setScheduleNumber(msg, 
      call CXSchedulerPacket.getScheduleNumber(schedMsg));
    return call SubCXRQ.requestSend(layerCount + 1, baseFrame, frameOffset, useMicro,
    microRef, tsLoc, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.sendHandled(error, layerCount - 1, atFrame,
    reqFrame, microRef, t32kRef, md, msg);
  }

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount + 1, baseFrame, frameOffset);
  }

  event void SubCXRQ.sleepHandled(error_t error, uint8_t layerCount, uint32_t atFrame, 
      uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame, reqFrame);
    }else{
      //TODO: update state
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame, frameOffset);
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.wakeupHandled(error, 
        layerCount, 
        atFrame, reqFrame);
    }else{
      //TODO update state
    }
  }

  command error_t CXRequestQueue.requestFrameShift(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    return call SubCXRQ.requestFrameShift(layerCount + 1, baseFrame, frameOffset,
      frameShift);
  }

  event void SubCXRQ.frameShiftHandled(error_t error,
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if ( layerCount){
      signal CXRequestQueue.frameShiftHandled(error, layerCount - 1, atFrame, reqFrame);
    }else{
      //TODO: update state
    }
  }

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      sched = (cx_schedule_t*)call Packet.getPayload(schedMsg, sizeof(cx_schedule_t));
      post init();
    }
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
}
