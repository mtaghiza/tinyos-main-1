/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
  provides interface SlotTiming;
  uses interface StateDump;
  uses interface Notify<uint32_t> as ActivityNotify;

  uses interface RadioStateLog;
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
  uint16_t mySlot = INVALID_SLOT;
  //ID of master node: this is used to fetch skew correction values.
  am_addr_t masterId = 0;
  
  //counter for validating that wakeups match up with sleeps.
  uint8_t wakeupPending = 0;

  uint32_t logBatch;
  
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
      cdbg(SCHED, "scs WNS cs %lu lss %lu\r\n", 
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
      cdbg(SCHED, "ss WNS\r\n");
      post wakeupNextSlot();
    }
  }
   
  //----------- Begin general utility functions -----

  //Get the slot number for a given frame.
  uint16_t slotNumber(uint32_t frame){
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
    uint32_t ret = lastCycleStart + (sn * sched->slotLength);

//    //This is to handle the case where we have not yet updated
//    //lastCycleStart but the new cycle will begin momentarily.
//    if (call SubCXRQ.nextFrame(FALSE) > (lastCycleStart + sched->cycleLength)){
//        return ret + sched->cycleLength;
//    }else{
      return ret;
//    }
  }
  
  //find out the distance of a given frame from the beginning of its
  //slot.
  uint32_t frameOfSlot(uint32_t frame){
    return frame - slotStart(slotNumber(frame));
  }
  
  //return whether or not the specified frame is owned by this node.
  bool isOwned(uint32_t frame){
    uint16_t sn =  slotNumber(frame);
    return (sn != INVALID_SLOT) && (sn == mySlot);
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
  
  command uint32_t SlotTiming.nextSlotStart(uint32_t fn){
    uint32_t nss = myNextSlotStart(fn);
    
    if (nss != INVALID_FRAME){
      nss += 1;
    } 
    return nss;
  }

  command uint32_t SlotTiming.lastSlotStart(){
    return slotStart(mySlot);
  }

  command uint32_t SlotTiming.framesLeftInSlot(uint32_t fn){
    uint32_t ss = slotStart(mySlot);
    if (fn >= ss && fn < ss + sched->slotLength){
      return (sched->slotLength) - (fn - ss);
    }else{
      return 0;
    }
  }

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
      uint32_t mns = myNextSlotStart(subNext);
      if (isOwned(subNext)){
        if (subNext == mns){
          //avoiding conflict with wakeup
          return subNext + 1;
        }else{
          return subNext;
        }
      }else{
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
      }else{
        cerror(SCHED, "ss.req sw %lu %u %lu %lu %li %x\r\n",
          lastCycleStart,
          sched->slotLength*(slotNumber(lastSlotStart)+1),
          call SkewCorrection.referenceFrame(masterId),
          call SkewCorrection.referenceTime(masterId),
          call SkewCorrection.getCorrection(masterId,
            sched->slotLength*(slotNumber(lastSlotStart)+1)),
          error);
        call StateDump.requestDump();
      }
      cdbg(SCHED, "rsw %lu + %u %x\r\n",
        lastCycleStart , sched->slotLength*(slotNumber(lastSlotStart)+1),
        error);
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
      cdbg(SCHED, "wh up\r\n");
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      if (wakeupPending){
        wakeupPending --;
      }else{
        cerror(SCHED, "Unexpected wakeup %lu\r\n", atFrame);
        call StateDump.requestDump();
      }
      if (error != SUCCESS){
        cerror(SCHED, "ss.wh %lu %lu %x\r\n", 
          atFrame, reqFrame, error);
        call StateDump.requestDump();
      }
      lastSlotStart = reqFrame;
      slotState = S_UNKNOWN;
      if (sched != NULL){
        uint32_t lb;
        uint16_t sn = slotNumber(atFrame);
        signal SlotNotify.slotStarted(sn);

        lb = call RadioStateLog.dump();
        if (lb){
          cinfo(RADIOSTATS, "LB %lu %u\r\n",
            lb, sn-1);
        }
        if (sn == (sched->activeSlots - 1)){
          cdbg(SCHED, "sw l %lu\r\n", atFrame);
          signal SlotNotify.lastSlot();
        } else if (sn < (sched->activeSlots - 1) ){
          cdbg(SCHED, "sw n %lu\r\n", atFrame);
          post wakeupNextSlot();
        } else {
          //woke up some time during the inactive period, shouldn't
          //  happen.
          cerror(SCHED, "inactive period wakeup %lu slot %u\r\n", 
            atFrame, sn);
          call StateDump.requestDump();
        }
      }
    }
  }
  
  event void ActivityNotify.notify(uint32_t atFrame){
    slotState = S_ACTIVE;
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
        && frameOfSlot(atFrame) > sched -> maxDepth){
      slotState = S_INACTIVE;
      post sleepToNextSlot();
    }
    //regardless of above logic, pass through handled events
    if (layerCount){
      signal CXRequestQueue.receiveHandled(error,
        layerCount - 1, 
        atFrame, reqFrame, didReceive, microRef, t32kRef,
        md, msg);
    }else{
      //there shouldn't be any RX requests originating at this layer.
      cerror(SCHED, "Unexpected rxHandled\r\n");
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
      cdbg(SCHED, "req slot sleep: %x @%lu\r\n", 
        error, 
        ns);
    } else {
      cerror(SCHED, "Slot sleep requested, but no wakeup pending\r\n");
      call StateDump.requestDump();
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
  command void ScheduleParams.setSlot(uint16_t slot){
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
      cerror(SCHED, "Unexpected terminal sendHandled\r\n");
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
  
  event void StateDump.dumpRequested(){
    cinfo(SCHED, "SSD %lu %lu\r\n", 
      lastCycleStart, lastSlotStart);
  }
}

