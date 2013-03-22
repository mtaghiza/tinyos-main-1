 #include "CXScheduler.h"
module CXSlaveSchedulerP{
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;

  uses interface Receive as ScheduleReceive;
} implementation {
  message_t msg_internal;
  message_t* schedMsg;

  cx_schedule_t* sched;
  
  enum { 
    S_OFF = 0x00,  
    S_SEARCH = 0x01,     //no schedule
    S_SYNCHED = 0x02,    //frame boundaries OK, got last schedule
    S_SOFT_SYNCH = 0x03, //frames are probably timed OK, but missed
                         //the last schedule.
  };

  uint8_t state = S_OFF;
  uint32_t lastWakeup;
  uint32_t nextWakeup;

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    if (isTX){
      if (state == S_SYNCHED){
        uint32_t subNext = call SubCXRQ.nextFrame(isTX);
        
        //TODO: return first frame of our next-owned slot.
        return 0;
      } else {
        //not synched, so we won't permit any TX.
        return 0;
      }
    }else{
      uint32_t subNext = call SubCXRQ.nextFrame(isTX);
      (nextWakeup+1) > subNext ? nextWakeup+1: subNext;
      return subNext;
    }
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    if(duration == 0){
      switch(state){
        case S_SYNCHED:
          duration = RX_DEFAULT_WAIT;
          break;
        case S_SOFT_SYNCH:
          duration = RX_DEFAULT_WAIT*2;
          break;
        case S_SEARCH:
          duration = RX_MAX_WAIT;
          break;
      }
    }
  }

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //frame timing acquired
    if (didReceive && state == S_SEARCH){
      state = S_SOFT_SYNCH;
    }

    //TODO: should also verify frame number correctness
    if (didReceive && state == S_SOFT_SYNCH 
        && sched->sn
        == call CXSchedulerPacket.getScheduleNumber(msg)){
      state = S_SYNCHED;
    }
    if (! didReceive && state == S_SEARCH){
      //TODO: handle fail-safe logic here. We should sleep the
      //  radio for a while and try again later.
    }
    if (layerCount){
      signal CXRequestQueue.receiveHandled(error,
        layerCount - 1, 
        atFrame, reqFrame, didReceive, microRef, t32kRef,
        md, msg);
    }else{
      //there shouldn't be any RX requests originating at this layer.
    }
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){
    if (sched == NULL || state != S_SYNCHED){
      return ERETRY;
    }

    call CXSchedulerPacket.setScheduleNumber(msg, 
      sched->sn);
    return call SubCXRQ.requestSend(layerCount + 1, baseFrame,
      frameOffset, useMicro, microRef, tsLoc, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (layerCount){
      signal SubCXRQ.sendHandled(error, 
        layerCount - 1,
        atFrame, reqFrame,
        microRef, t32kRef, 
        md, msg);
    }else{
      //TODO: from this layer: was a CLAIM packet.
    }
  }

  event message_t* ScheduleReceive.receive(message_t* msg, 
      void* payload, uint8_t len ){
    message_t* ret = schedMsg;
    sched = (cx_schedule_t*)payload;
    schedMsg = msg;
    state = S_SYNCHED;
    return ret;
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
      //TODO update state
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
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      //TODO: update state

    }
  }

  command error_t CXRequestQueue.requestFrameShift(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, int32_t frameShift){
    return call SubCXRQ.requestFrameShift(layerCount + 1, 
      baseFrame, frameOffset, frameShift);
  }

  event void SubCXRQ.frameShiftHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.frameShiftHandled(error, 
        layerCount - 1, 
        atFrame, reqFrame);
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
  event void SubSplitControl.stopDone(error_t error){
    if (error == SUCCESS){
      state = S_OFF;
    }
    signal SplitControl.stopDone(error);
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      state = S_SEARCH;
    }
    signal SplitControl.startDone(error);
  }
}
