
 #include "CXScheduler.h"
 #include "CXSchedulerDebug.h"
module SlotSchedulerP{
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface CXNetworkPacket;

  provides interface ScheduleParams;
  uses interface SkewCorrection;
  provides interface SlotNotify;
} implementation {
  message_t msg_internal;
  message_t* schedMsg = &msg_internal;

  cx_schedule_t* sched;
  
  enum{
    S_UNKNOWN = 0x00,
    S_INACTIVE = 0x01,
    S_ACTIVE = 0x02,
  };
  uint8_t slotState = S_UNKNOWN;

  uint32_t lastSlotStart = INVALID_FRAME;
  uint32_t lastCycleStart = INVALID_FRAME;
  
  uint32_t lastSleep = INVALID_FRAME;
  uint32_t nextSleep = INVALID_FRAME;
  uint32_t nextWakeup = INVALID_FRAME;

  uint32_t mySlot = INVALID_SLOT;

  uint8_t wakeupPending = 0;
  am_addr_t masterId = 0;

  task void wakeupNextSlot();

  command void ScheduleParams.setSchedule(cx_schedule_t* schedule){
    sched = schedule;
  }

  command void ScheduleParams.setCycleStart(uint32_t cycleStart){
    lastCycleStart = cycleStart;
    while (sched!= NULL && lastSlotStart < lastCycleStart){
      lastSlotStart += sched -> slotLength;
    }
    if (lastSlotStart == INVALID_FRAME 
        && cycleStart != INVALID_FRAME){
      lastSlotStart = lastCycleStart;
    }
    if (!wakeupPending && sched != NULL){
      post wakeupNextSlot();
    }
  }

  command void ScheduleParams.setSlot(uint32_t slot){
    mySlot = slot;
  }

  command void ScheduleParams.setMasterId(am_addr_t addr){
    masterId = addr;
  }

  uint32_t slotNumber(uint32_t frame){
    if (sched == NULL){
      return INVALID_SLOT;
    }
    if (frame < lastCycleStart){
      return INVALID_SLOT;
    }else{
      frame -= lastCycleStart;
      while (frame >= sched->cycleLength){
        frame -= sched->cycleLength;
      }
      return frame/sched->slotLength;
    }
  }

  uint32_t slotStart(uint32_t sn){
    return lastCycleStart + (sn * sched->slotLength);
  }

  uint32_t frameOfSlot(uint32_t frame){
    return frame - slotStart(slotNumber(frame));
  }

  bool isOwned(uint32_t frame){
    uint32_t sn =  slotNumber(frame);
    return sn != INVALID_SLOT && sn == mySlot;
  }

  uint32_t myNextSlotStart(uint32_t frame){
    if (mySlot == INVALID_SLOT){
      return INVALID_FRAME;
    }else{
      uint32_t ss = slotStart(mySlot);
      if (ss < frame){
        return ss + sched->cycleLength;
      } else {
        return ss;
      }
    }
  }

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    uint32_t subNext = call SubCXRQ.nextFrame(isTX);
    if (subNext == INVALID_FRAME){
      return subNext;
    }
    if (isTX){
      if (isOwned(slotNumber(subNext) )){
        if (subNext == myNextSlotStart(subNext)){
          //avoiding conflict with wakeup
          return subNext + 1;
        }else{
          return subNext;
        }
      }else{
        uint32_t mns = myNextSlotStart(subNext);
        return mns == INVALID_FRAME? mns : mns + 1;
      }
    }else{
      //If we are awake at subNext: return subNext.
      //  - lastSlotStart < subNext
      //  - lastSleep is INVALID_FRAME or lastSleep < lastSlotStart
      bool awake = ((lastSleep < lastSlotStart && lastSlotStart < subNext) || (lastSleep == INVALID_FRAME)) && (lastSlotStart != INVALID_FRAME);
      if (awake){
        if (sched != NULL && subNext == lastSlotStart + sched->slotLength){
          return subNext + 1;
        }else{
          return subNext;
        }
      }else if (sched != NULL && lastSlotStart != INVALID_FRAME){
        uint32_t nextSlotStart = lastSlotStart ;
        while (nextSlotStart < subNext){
          nextSlotStart += sched->slotLength + 1;
        }
        return nextSlotStart; 
      }else{
        //If we don't know, return subNext
        return subNext;
      }
    }
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    if (msg == NULL){
      printf_SCHED("sched.cxrq.rr null\r\n");
      return EINVAL;
    }
    if(duration == 0){
      if (sched == NULL){
        duration = RX_MAX_WAIT;
      }else{
        duration = RX_DEFAULT_WAIT;
      }
    }
    return call SubCXRQ.requestReceive(layerCount + 1,
      baseFrame, frameOffset, 
      useMicro, microRef,
      duration,
      NULL, msg);
  }

  task void sleepToNextSlot(){
    uint32_t ns = call SubCXRQ.nextFrame(FALSE);
//    printf_SCHED("stns\r\n");
    //OK to sleep if either we have the next slot wakeup queued OR
    //this is the last slot (and we'll get woken up at the start of
    //the next cycle.
    if (wakeupPending || slotNumber(ns) == (sched->activeSlots-1)){
      error_t error = call SubCXRQ.requestSleep(0,
        ns,
        0);
      printf_SCHED("req slot sleep: %x @%lu\r\n", 
        error, 
        ns);
      if (error == SUCCESS){
        nextSleep = ns;
      }
    } else {
      printf("Slot sleep requested, but no wakeup pending\r\n");
    }
  }

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (sched != NULL 
        && !didReceive 
        && slotState == S_UNKNOWN 
        && frameOfSlot(atFrame) >= sched -> maxDepth){
      //We didn't receive anything, we had not yet ascertained that
      //this was an active slot, and according to the schedule, we
      //should have received something by this point if anything was
      //being transmitted.
      //We assume the slot is not in use and sleep until the next slot
      //start.
      slotState = S_INACTIVE;
      post sleepToNextSlot();
    }else{
      if (didReceive){
        slotState = S_ACTIVE;
      }else{
        //did not receive
      }
    }
    //regardless of above logic, pass through handled events
    if (layerCount){
      signal CXRequestQueue.receiveHandled(error,
        layerCount - 1, 
        atFrame, reqFrame, didReceive, microRef, t32kRef,
        md, msg);
    }else{
      //there shouldn't be any RX requests originating at this layer.
      printf("Unexpected rxHandled\r\n");
    }
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){

    //don't want to go to sleep here
    slotState = S_ACTIVE;
    return call SubCXRQ.requestSend(layerCount + 1, baseFrame,
      frameOffset, useMicro, microRef, tsLoc, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (layerCount){
      signal CXRequestQueue.sendHandled(error, 
        layerCount - 1,
        atFrame, reqFrame,
        microRef, t32kRef, 
        md, msg);
    }else{
      //nothing should be originating here
      printf("Unexpected terminal sendHandled\r\n");
    }
  }

  task void wakeupNextSlot(){
    error_t error;
    //TODO: apply skew correction
    error = call SubCXRQ.requestWakeup(0,
      lastCycleStart,
      sched->slotLength*(slotNumber(lastSlotStart)+1));
    if (error == SUCCESS){
      wakeupPending ++; 
      nextWakeup = lastCycleStart +
        sched->slotLength*(slotNumber(lastSlotStart)+1);
    }
    printf_SCHED("req sw: %x p %u\r\n",
      error, wakeupPending);
  }

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount + 1, baseFrame, frameOffset);
  }

  event void SubCXRQ.sleepHandled(error_t error, uint8_t layerCount, uint32_t atFrame, 
      uint32_t reqFrame){
//    printf_SCHED("SH %lu\r\n", atFrame);
    if (layerCount){
      signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame, reqFrame);
    }else{
      lastSleep = atFrame;
//      printf_SCHED("sleep %x @%lu\r\n", error, atFrame);
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    //Do not apply skew correction: will come from above.
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame, frameOffset);
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
//    printf_SCHED("WH %lu p %u\r\n", atFrame, wakeupPending);
    if (layerCount){
      printf_SCHED("wh up\r\n");
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      if (wakeupPending){
        wakeupPending --;
      }else{
        printf("Unexpected wakeup\r\n");
      }

//      printf("wakeup %x @%lu\r\n", error, atFrame);
      lastSlotStart = atFrame;
      slotState = S_UNKNOWN;
      if (sched != NULL){
        uint32_t sn = slotNumber(atFrame);
        if (sn == (sched->activeSlots - 1)){
          //notify the layer above
          //that the last slot is completing. That layer 
          //will request the cycle sleep/wakeup as needed.
          //previous impl marked nextSleep/nextWakeup so that
          //nextFrame didn't allow stuff to happen during the inactive
          //periods: we don't need (or want) to do this, because now
          //the layer above will handle the large-scale cycling
          signal SlotNotify.lastSlot();
        } else if (sn < (sched->activeSlots - 1) ){
          //prior to last active slot: next slot
          post wakeupNextSlot();
        } else {
          //woke up some time during the inactive period, shouldn't
          //  happen.
          printf("inactive period wakeup %lu slot %lu\r\n", 
            atFrame, sn);
        }
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
      printf("Unexpected frame shift handled\r\n");
    }
  }

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }
  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  event void SubSplitControl.startDone(error_t error){
    signal SplitControl.startDone(error);
  }
}

