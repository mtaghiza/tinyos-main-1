 #include "CXScheduler.h"
module CXSlaveSchedulerP{
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface CXNetworkPacket;

  uses interface Receive as ScheduleReceive;
} implementation {
  message_t msg_internal;
  message_t* schedMsg = &msg_internal;

  cx_schedule_t* sched;
  bool startDonePending = FALSE;
  
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
  uint32_t lastSleep;
  uint32_t nextSleep;

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    if (isTX){
      if (state == S_SYNCHED){
//        uint32_t subNext = call SubCXRQ.nextFrame(isTX);
        //TODO: return next frame of our current or next-owned slot.
        return 0;
      } else {
        //not synched, so we won't permit any TX.
        return 0;
      }
    }else{
      uint32_t subNext = call SubCXRQ.nextFrame(isTX);
      //if the sub-layer says next frame is during duty-cycled period,
      //then push it forward to just after the next wakeup.
      if (subNext >= nextSleep && subNext <= nextWakeup + 1){
        return nextWakeup + 1;
      }else{
        //this is for the case where we didn't sleep this slot. avoid
        //the conflict here if we can see it coming.
        if (subNext == nextWakeup){
          return nextWakeup + 1;
        } else {
          return subNext;
        }
      }
    }
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    if (msg == NULL){
      printf("sched.cxrq.rr null\r\n");
      return EINVAL;
    }
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
    return call SubCXRQ.requestReceive(layerCount + 1,
      baseFrame, frameOffset, 
      FALSE, 0,
      duration,
      NULL, msg);
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

  task void reportSched(){
    printf("RX Sched: %p sn %u cl %lu sl %lu md %u na %u ts %lu\r\n", 
      sched, 
      sched->sn,
      sched->cycleLength, 
      sched->slotLength, 
      sched->maxDepth,
      sched->numAssigned,
      sched->timestamp);
  }
  
  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;
  //to keep things simple, alpha (EWMA adaptation rate) has to be 1/n for some n.
  //at alpha=1, no history. v_i = ((v_(i-1)*0) + cur)/1
  int32_t alphaInv = 1;
  int32_t cumulativeTpf = 0;

  #ifndef TPF_DECIMAL_PLACES 
  #define TPF_DECIMAL_PLACES 8
  #endif

  task void updateSkew(){
    if (lastTimestamp != 0 && lastCapture != 0 && lastOriginFrame != 0){
      int32_t remoteElapsed = sched->timestamp - lastTimestamp;
      int32_t localElapsed = 
        call CXNetworkPacket.getOriginFrameStart(schedMsg) -
        lastCapture;
      int32_t framesElapsed = 
        call CXNetworkPacket.getOriginFrameNumber(schedMsg) -
        lastOriginFrame;
      //positive = we are slow = require shift forward
      int32_t delta = remoteElapsed - localElapsed;

      //this is fixed point, TPF_DECIMAL_PLACES bits after decimal
      int32_t tpf = (delta << TPF_DECIMAL_PLACES) / framesElapsed;
      //next EWMA step
      //n.b. we let TPF = 0 initially to keep things simple. In
      //general, we should be reasonably close to this. 
      cumulativeTpf = (tpf+(cumulativeTpf * (alphaInv-1)))/alphaInv;
      printf("local %lu - %lu = %lu\r\n",
        call CXNetworkPacket.getOriginFrameStart(schedMsg),
        lastCapture,
        localElapsed);
      printf("remote %lu - %lu = %lu\r\n", 
        sched->timestamp,
        lastTimestamp,
        remoteElapsed);
      printf("frames %lu - %lu = %lu\r\n",
        call CXNetworkPacket.getOriginFrameNumber(schedMsg),
        lastOriginFrame,
        framesElapsed);
      printf("delta raw %lx tpf raw %lx over 160: %li 320: %li 640: %li\r\n",
        delta,
        tpf, 
        (tpf*160)>>TPF_DECIMAL_PLACES,
        (tpf*320)>>TPF_DECIMAL_PLACES,
        (tpf*640)>>TPF_DECIMAL_PLACES);
      printf("ctpf over 320 %li\r\n", 
        (cumulativeTpf*320)>>TPF_DECIMAL_PLACES);

    }
    lastTimestamp = sched -> timestamp;
    lastCapture = call CXNetworkPacket.getOriginFrameStart(schedMsg);
    lastOriginFrame = call CXNetworkPacket.getOriginFrameNumber(schedMsg);
  }

  event message_t* ScheduleReceive.receive(message_t* msg, 
      void* payload, uint8_t len ){
    message_t* ret = schedMsg;
    error_t error;
    sched = (cx_schedule_t*)payload;
    schedMsg = msg;
    state = S_SYNCHED;

    //sleep at the end of the last assigned slot
    error = call SubCXRQ.requestSleep(0,
      call CXNetworkPacket.getOriginFrameNumber(msg), 
      sched->slotLength*sched->numAssigned);
    if (error != SUCCESS){
      printf("sched.rs: %x\r\n", error);
    }else{
      nextSleep = call CXNetworkPacket.getOriginFrameNumber(msg) + 
        sched->slotLength*sched->numAssigned;
    }

    //wake up 1 frame prior to the root's next scheduled transmission
    error = call SubCXRQ.requestWakeup(0,
      call CXNetworkPacket.getOriginFrameNumber(msg),
      sched->cycleLength - 1);
    if (error != SUCCESS){
      printf("sched.rw: %x\r\n", error);
    }else{
      nextWakeup = call CXNetworkPacket.getOriginFrameNumber(msg) 
        + sched->cycleLength - 1;
    }

    post reportSched();
    #if CX_ENABLE_SKEW_CORRECTION == 1
    post updateSkew();
    #else
    #warning "CX skew correction disabled"
    #endif
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
      //TODO: update state
//      printf("sleep %x @%lu\r\n", error, atFrame);
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    //TODO: request frame-shift prior to wake up to restore synch to root
    //schedule. 
    //TODO: internal calls should also be routed through this step.
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame, frameOffset);
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
//      printf("wh up\r\n");
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      if (startDonePending == TRUE){
        startDonePending = FALSE;
        signal SplitControl.startDone(error);
      }
      //TODO: update state
//      printf("wakeup %x @%lu\r\n", error, atFrame);
      lastWakeup = atFrame;
      if (state == S_SYNCHED){
        //ok, set wakeup for next slot boundary 
      }
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
      error = call SubCXRQ.requestWakeup(0, 
        call SubCXRQ.nextFrame(FALSE), 2);

    }
    if (error == SUCCESS){
      startDonePending = TRUE;
      state = S_SEARCH;
    }
  }
}
