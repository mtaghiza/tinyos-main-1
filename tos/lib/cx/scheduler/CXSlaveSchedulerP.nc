module CXSlaveSchedulerP{
  provides interface SplitControl;
  uses interface SubSplitControl;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface CXPacketMetadata;

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

  command error_t CXRequestQueue.requestReceive(uint32_t baseFrame, 
      int32_t frameOffset, 
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

    signal CXRequestQueue.receiveHandled(error,
      atFrame, reqFrame, didReceive, microRef, t32kRef,
      md, msg);
  }

  command error_t requestSend(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){
    if (sched == NULL || state != S_SYNCHED){
      return ERETRY;
    }

    call CXSchedulerPacket.setSchedulerNumber(msg, 
      sched->sn);
    return call SubCXRQ.requestSend(baseFrame,
      frameOffset, useMicro, microRef, tsLoc, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    //TODO: only signal it up if this was not a CLAIM packet (from
    //this layer)
    signal SubCXRQ.sendHandled(error, 
      atFrame, reqFrame,
      microRef, t32kRef, 
      md, msg);
  }

  event void ScheduleReceive.receive(message_t* msg, 
      void* payload, uint8_t len ){
    message_t* ret = schedMsg;
    sched = (cx_schedule_t*)pl;
    schedMsg = msg;
    state = S_SYNCHED;
    return ret;
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
  }

  event void SubCXRQ.frameShiftHandled(error_t error, uint32_t atFrame,
    uint32_t reqFrame);

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
    signal SplitControl.stopDone();
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      state = S_SEARCH;
    }
    signal SplitControl.startDone(error);
  }
}
