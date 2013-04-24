 #include "CXScheduler.h"
 #include "CXSchedulerDebug.h"
module SlotSchedulerP{
  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface CXNetworkPacket;

  uses interface SkewCorrection;
  provides interface SlotNotify;
  provides interface ScheduleParams;
} implementation {
  
  //enums/vars for determining when a slot is idle.
  enum{
    S_UNKNOWN = 0x00,
    S_INACTIVE = 0x01,
    S_ACTIVE = 0x02,
  };
  uint8_t slotState = S_UNKNOWN;
  
  //variables for tracking the order of sleep/wakeup and for setting
  //slot wakeups. 
  uint32_t lastSlotStart = INVALID_FRAME;
  uint32_t lastCycleStart = INVALID_FRAME;
  uint32_t lastSleep = INVALID_FRAME;
  
  //current schedule settings
  const cx_schedule_t* sched;
  uint32_t mySlot = INVALID_SLOT;
  //ID of master node: this is used to fetch skew correction values.
  am_addr_t masterId = 0;
  
  //counter for validating that wakeups match up with sleeps.
  uint8_t wakeupPending = 0;
  
  //forward declarations
  task void wakeupNextSlot();
  task void sleepToNextSlot();
  

  /**
   *  Set cycle/slot start as indicated. If there are no wakeups
   *  pending and we have the schedule (e.g. this is the first time
   *  we've been given the schedule), scheduled the first slot wakeup.
   */
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
      printf("scs WNS cs %lu lss %lu\r\n", 
        cycleStart, 
        lastCycleStart);
      post wakeupNextSlot();
    }
  }
  
  /**
   *  Set schedule as indicated. schedule first slot wakeup if needed.
   **/
  command void ScheduleParams.setSchedule(cx_schedule_t* schedule){
    sched = schedule;
    if (!wakeupPending && sched != NULL && lastSlotStart != INVALID_FRAME){
      printf("ss WNS\r\n");
      post wakeupNextSlot();
    }
  }
   
  //----------- Begin general utility functions -----

  //Get the slot number for a given frame.
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
  
  //get the first frame of a given slot
  uint32_t slotStart(uint32_t sn){
    return lastCycleStart + (sn * sched->slotLength);
  }
  
  //find out the distance of a given frame from the beginning of its
  //slot.
  uint32_t frameOfSlot(uint32_t frame){
    return frame - slotStart(slotNumber(frame));
  }
  
  //return whether or not the specified frame is owned by this node.
  bool isOwned(uint32_t frame){
    uint32_t sn =  slotNumber(frame);
    return sn != INVALID_SLOT && sn == mySlot;
  }
  
  //return the first frame of the next occurrence of this node's
  //assigned slot. Note that it's possible that this returns a frame
  //from the next cycle, and so it could be reassigned during this
  //cycle. We assume that such assignments are relatively rare, so we
  //don't worry too much about a node transmitting some data outside
  //of its designated time.
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

  //----- End utility functions
  

  /**
   *  In a nutshell: 
   *  - get the next frame from the layer below. 
   *  - push TX requests forward to our next slot as needed
   *  - push non-TX requests forward to the next frame where we are
   *    not sleeping, as needed.
   **/
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
      bool awake = (lastSlotStart != INVALID_FRAME) 
        && ((lastSleep < lastSlotStart && lastSlotStart < subNext) || (lastSleep == INVALID_FRAME));

      if (awake){
        if (sched != NULL && subNext == lastSlotStart + sched->slotLength){
          //avoid conflict with next slot's wakeup.
          return subNext + 1;
        }else{
          return subNext;
        }
      }else if (sched != NULL && lastSlotStart != INVALID_FRAME){
        //asleep, but we have the schedule: right after next slot
        //wakeup.
        uint32_t nextSlotStart = lastSlotStart;
        while (nextSlotStart < subNext){
          nextSlotStart += sched->slotLength + 1;
        }
        return nextSlotStart; 
      }else{
        //If we don't know, return subNext: this would be for cases
        //where we have no schedule, for instance.
        return subNext;
      }
    }
  }
  
  /**
   *  Use the current schedule information to set a wakeup for the
   *  beginning of the next slot.  This uses the skew correction data
   *  and the master's node ID to figure out when exactly to set the
   *  wakeup.
   **/
  task void wakeupNextSlot(){
    error_t error;
    //if we're in the last slot, don't schedule the next wakeup.
    if (slotNumber(lastSlotStart) < sched->activeSlots - 1){
      error = call SubCXRQ.requestWakeup(0,
        lastCycleStart,
        sched->slotLength*(slotNumber(lastSlotStart)+1),
        call SkewCorrection.referenceFrame(masterId),
        call SkewCorrection.referenceTime(masterId),
        call SkewCorrection.getCorrection(masterId,
          sched->slotLength*(slotNumber(lastSlotStart)+1)));
      if (error == SUCCESS){
        wakeupPending ++; 
      }
      printf_SCHED("req sw: %lu %x p %u\r\n",
        lastCycleStart + sched->slotLength*(slotNumber(lastSlotStart)+1),
        error, wakeupPending);
    }
  }

  /**
   * Update last slot-start and either schedule the next slot-start
   * wakeup OR signal the role-scheduler that this is the last slot of
   * the cycle (so that it can sleep/wakeup as needed).
   **/
  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      printf_SCHED("wh up\r\n");
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      if (wakeupPending){
        wakeupPending --;
      }else{
        printf("Unexpected wakeup\r\n");
      }

      lastSlotStart = atFrame;
      slotState = S_UNKNOWN;
      if (sched != NULL){
        uint32_t sn = slotNumber(atFrame);
        if (sn == (sched->activeSlots - 1)){
          signal SlotNotify.lastSlot();
        } else if (sn < (sched->activeSlots - 1) ){
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
  

  /**
   *  Pass through receive handled events. If a slot is detected as
   *  being inactive (no RX within sched->maxDepth frames), sleep.
   **/
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
      slotState = S_INACTIVE;
      post sleepToNextSlot();
    }else{
      if (didReceive){
        slotState = S_ACTIVE;
      }else{
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
  
  /**
   *  Verify that there is either a slot wakeup scheduled OR this is
   *  the last active slot (implying cycle wakeup from above is
   *  pending), and then sleep.
   *  
   **/
  task void sleepToNextSlot(){
    uint32_t ns = call SubCXRQ.nextFrame(FALSE);
    if (wakeupPending || slotNumber(ns) == (sched->activeSlots-1)){
      error_t error = call SubCXRQ.requestSleep(0,
        ns,
        0);
      if (error != SUCCESS){
        printf("req slot sleep: %x @%lu\r\n", error, ns);
      }
      printf_SCHED("req slot sleep: %x @%lu\r\n", 
        error, 
        ns);
    } else {
      printf("Slot sleep requested, but no wakeup pending\r\n");
    }
  }

  /**
   *  Pass through and prevent this slot from being flagged as
   *  inactive.
   */
  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    slotState = S_ACTIVE;
    return call SubCXRQ.requestSend(layerCount + 1, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  //pass-through, record when sleep occurs for use in CXRQ.nextFrame.
  event void SubCXRQ.sleepHandled(error_t error, uint8_t layerCount, uint32_t atFrame, 
      uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame, reqFrame);
    }else{
      lastSleep = atFrame;
    }
  }

  
  //--- self-explanatory functions below

  /**
   *  Assign a specific owned slot.
   **/
  command void ScheduleParams.setSlot(uint32_t slot){
    mySlot = slot;
  }
  
  /**
   *  Set the schedule master's ID: this is used for skew correction
   *  lookup.
   **/
  command void ScheduleParams.setMasterId(am_addr_t addr){
    masterId = addr;
  }

  //---- 100% Pass throughs below
  command error_t CXRequestQueue.requestReceive(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    return call SubCXRQ.requestReceive(layerCount + 1,
      baseFrame, frameOffset, 
      useMicro, microRef,
      duration,
      NULL, msg);
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
  
  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount + 1, baseFrame, frameOffset);
  }

  //N.B. skew correction is NOT applied here (will come from above if needed)
  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame,
    frameOffset, refFrame, refTime, correction);
  }
  
}

