
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

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    return 0;
  }

  command error_t CXRequestQueue.requestReceive(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call SubCXRQ.requestReceive(baseFrame, frameOffset,
      useMicro, microRef, 
      duration, 
      md, msg);
  }

  event void SubCXRQ.receiveHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal SubCXRQ.receiveHandled(error, atFrame, reqFrame,
      didReceive, microRef, t32kRef, md, msg);
  }

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){

    call CXSchedulerPacket.setScheduleNumber(msg, 
      call CXSchedulerPacket.getScheduleNumber(schedMsg));
    return call SubCXRQ.requestSend(baseFrame, frameOffset, useMicro,
    microRef, tsLoc, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
  }

  command error_t CXRequestQueue.requestSleep(uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestSleep(baseFrame, frameOffset);
  }
  event void SubCXRQ.sleepHandled(error_t error, uint32_t atFrame, 
      uint32_t reqFrame){
    //TODO: only signal up if we didn't request it
    signal CXRequestQueue.sleepHandled(error, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestWakeup(uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestWakeup(baseFrame, frameOffset);
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame){
    //TODO: only signal up if we didn't request it
    signal CXRequestQueue.wakeupHandled(error, atFrame, reqFrame);
  }

  command error_t CXRequestQueue.requestFrameShift(uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    return call SubCXRQ.requestFrameShift(baseFrame, frameOffset,
      frameShift);
  }

  event void SubCXRQ.frameShiftHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame){
    //TODO: only signal if we didn't request it 
    signal CXRequestQueue.frameShiftHandled(error, atFrame, reqFrame);
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
      //TODO: start duty cycling
      //TODO: set up schedule
      //TODO: schedule send
    }
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
}
