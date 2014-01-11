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
 #include "fixedPointUtils.h"
 #include "CXLink.h"
 #include "CXNetwork.h"
module CXSlaveSchedulerStaticP{
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface CXRequestQueue;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface Receive as ScheduleReceive;
  uses interface SkewCorrection;
  uses interface ScheduleParams;
  uses interface CXSchedulerPacket;
  uses interface CXNetworkPacket;
  uses interface CXLinkPacket;
  uses interface SlotNotify;
  uses interface Packet;
  uses interface RoutingTable;
  uses interface ActiveMessageAddress;
  uses interface StateDump;
  uses interface RadioStateLog;
} implementation {
  message_t msg_internal;
  message_t* schedMsg = &msg_internal;

  cx_schedule_t* sched;
  bool startDonePending = FALSE;
  
  //were we synchronized at the time that the last schedule was
  //received?
  bool synchReceived;
  bool scheduleReceived = FALSE;
  uint8_t missedCount = 0;
  am_addr_t masterId;
  
  enum { 
    S_OFF = 0x00,  
    S_SEARCH = 0x01,     //no schedule
    S_SYNCHED = 0x02,    //frame boundaries OK, got last schedule
    S_SOFT_SYNCH = 0x03, //frames are probably timed OK, but missed
                         //the last schedule.
  };

  uint8_t state = S_OFF;
  uint32_t lastCycleStart;
  
  uint16_t mySlot = INVALID_SLOT;

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    uint32_t subNext = call SubCXRQ.nextFrame(isTX);
    if (subNext == INVALID_FRAME){
      return INVALID_FRAME;
    }
    if (isTX){
      if (state == S_SYNCHED){
        //we're synched, so we rely on the slot scheduler to figure
        //out when our next slot is.
        return subNext;
      } else {
        //not synched, so we won't permit any TX.
        return INVALID_FRAME;
      }
    }else{
      if (lastCycleStart != INVALID_FRAME && sched != NULL){
        //we have a schedule, so we can figure out when our sleep/wake
        //period is. cycleWake is the next wakeup, cycleSleep
        //is the immediately-preceding sleep.
        uint32_t cycleWake = lastCycleStart;
        uint32_t cycleSleep;
        while (cycleWake < subNext){
          cycleWake += sched->cycleLength;
        }
        cycleSleep = cycleWake 
          - (sched->cycleLength) 
          + (sched->slotLength)*(sched->activeSlots)
          + 1;
        
        //if subnext is during the sleep period, push it back to
        //1+wake
        if (subNext >= cycleSleep && subNext <= cycleWake){
          return cycleWake + 1;
        }else{
        //otherwise, it's good to go
          return subNext;
        }
      }else{
        //if we don't have a schedule, use result from below.
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
      cwarn(SCHED, "sched.cxrq.rr null\r\n");
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
      useMicro, microRef,
      duration,
      NULL, msg);
  }

  void startSearch(){
    state = S_SEARCH;
    mySlot = INVALID_SLOT;
    sched = NULL;
    call ScheduleParams.setSlot(mySlot);
    call ScheduleParams.setSchedule(sched);
  }

  event void SubCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (didReceive){
      //frame timing acquired
      if (state == S_SEARCH){
        state = S_SOFT_SYNCH;
      }
      if (state == S_SOFT_SYNCH 
          && sched != NULL 
          && sched->sn == call CXSchedulerPacket.getScheduleNumber(msg)){
        //bring forward lastCycleStart if needed
        while (atFrame > (lastCycleStart + sched->cycleLength)){
          lastCycleStart += sched->cycleLength;
        }
        call ScheduleParams.setCycleStart(lastCycleStart);
        {
          uint32_t cycleLocalOrigin = call CXNetworkPacket.getOriginFrameNumber(msg) - lastCycleStart;
          if (cycleLocalOrigin != call CXSchedulerPacket.getOriginFrame(msg)){
            cinfo(SCHED, "FM %lu <> %lu - %lu\r\n",
              call CXSchedulerPacket.getOriginFrame(msg),
              call CXNetworkPacket.getOriginFrameNumber(msg),
              lastCycleStart);
            startSearch();
          } else {
            state = S_SYNCHED;
          }
        }
      }
    }else{
      //did not receive
      if (state == S_SEARCH){
        //TODO: handle fail-safe logic here. We should sleep the
        //  radio for a while and try again later.
      }else if (state == S_SOFT_SYNCH){
        //TODO: fail-safe logic: after N soft-synch RX's with no data,
        //go to search.
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
      cerror(SCHED, "Unexpected rxHandled\r\n");
    }
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    if (sched == NULL || state != S_SYNCHED){
      return EOFF;
    }

    call CXSchedulerPacket.setScheduleNumber(msg, 
      sched->sn);
    if (call CXNetworkPacket.getTTL(msg) == 0 ){
      call CXNetworkPacket.setTTL(msg, sched->maxDepth);
    }
    call CXSchedulerPacket.setOriginFrame(msg, 
      (baseFrame + frameOffset - lastCycleStart)%sched->cycleLength);
    return call SubCXRQ.requestSend(layerCount + 1, baseFrame,
      frameOffset, txPriority, useMicro, microRef, md, msg);
  }

  event void SubCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (layerCount){
      if (error == SUCCESS && state != S_SYNCHED){
        //we were not synched, so it might have been sent
        //off-schedule.
        error = EOFF;
      }
      signal CXRequestQueue.sendHandled(error, 
        layerCount - 1,
        atFrame, reqFrame,
        microRef, t32kRef, 
        md, msg);
    }
  }

  task void reportSched(){
    cinfo(SCHED, "SCHED RX %u %u %u %lu %lu\r\n",
      sched->sn,
      call CXLinkPacket.getSource(schedMsg),
      call CXNetworkPacket.getSn(schedMsg),
      sched->cycleStartFrame,
      lastCycleStart);
//    cinfo(SCHED, "RX Sched");
//    cinfo(SCHED, ": %p %p sn %u cl %lu sl %u md %u ts %lu",
//      schedMsg,
//      sched, 
//      sched->sn,
//      sched->cycleLength, 
//      sched->slotLength, 
//      sched->maxDepth,
//      sched->timestamp);
//
//    cinfo(SCHED, "\r\n");
  }

  
  task void updateSkew(){
    error_t error = call SkewCorrection.addMeasurement(
      call CXLinkPacket.getSource(schedMsg),
      synchReceived,
      sched->timestamp,
      call CXNetworkPacket.getOriginFrameNumber(schedMsg),
      call CXNetworkPacket.getOriginFrameStart(schedMsg));
    if (SUCCESS != error){
      cwarn(SKEW, "sc.am: %x %lu %lu %lu\r\n",
        error,
        sched->timestamp,
      call CXNetworkPacket.getOriginFrameNumber(schedMsg),
      call CXNetworkPacket.getOriginFrameStart(schedMsg));
    }
  }

  task void claimSlotTask(){
    mySlot = call ActiveMessageAddress.amAddress();
    call ScheduleParams.setSlot(mySlot);
  }

  event message_t* ScheduleReceive.receive(message_t* msg, 
      void* payload, uint8_t len ){
    message_t* ret = schedMsg;
    synchReceived = (state == S_SYNCHED);
    if (!synchReceived){
      cinfo(SCHED, "Synch gained\r\n");
    }
    sched = (cx_schedule_t*)payload;
    schedMsg = msg;
    state = S_SYNCHED;
    scheduleReceived = TRUE;

    //frames-from-start = Master OFN - master start 
    //slave OFN - frames-from-start = slave start
    lastCycleStart = 
      call CXNetworkPacket.getOriginFrameNumber(msg) -
      call CXSchedulerPacket.getOriginFrame(msg);
    cdbg(SCHED, "LO %lu RO %lu RCSF %lu\r\n",
      call CXNetworkPacket.getOriginFrameNumber(msg),
      call CXSchedulerPacket.getOriginFrame(msg),
      sched->cycleStartFrame);

    call ScheduleParams.setSchedule(sched);
    call ScheduleParams.setCycleStart(lastCycleStart);
    masterId = call CXLinkPacket.getSource(msg);
    call ScheduleParams.setMasterId(masterId);

    call RoutingTable.setDefault(sched->maxDepth);
    
    if (mySlot == INVALID_SLOT){
      post claimSlotTask();
    }
    post reportSched();
    post updateSkew();
    return ret;
  }

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    return call SubCXRQ.requestSleep(layerCount + 1, baseFrame, frameOffset);
  }
  
  uint32_t lastSleepHandled;

  event void SubCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame, reqFrame);
    }else{
      //sleep from this layer @ end of last active slot
      uint32_t lb = call RadioStateLog.dump();
      lastSleepHandled = atFrame;
      if (lb && sched != NULL){
        cinfo(RADIOSTATS, "LB %lu %u\r\n",
          lb, sched->activeSlots);
      }
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, uint32_t refFrame, uint32_t refTime, int32_t correction){
    //probably won't have any calls to this coming in from above
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame,
    frameOffset, refFrame, refTime, correction);
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      cdbg(SCHED, "wh up\r\n");
      signal CXRequestQueue.wakeupHandled(error, layerCount - 1, atFrame, reqFrame);
    }else {
      if (startDonePending){
        startDonePending = FALSE;
        signal SplitControl.startDone(SUCCESS);
      } else {
        uint32_t lb = call RadioStateLog.dump();
        state = S_SOFT_SYNCH;

        //log radio stats for the preceding idle period.
        if (lb){
          cinfo(RADIOSTATS, "LB %lu -1\r\n", lb);
          //indicate how long the idle period was.
          cinfo(RADIOSTATS, "LBI %lu %lu %lu\r\n", 
            lb, lastSleepHandled, atFrame);
        }

        //at this layer: wakeup is at start of cycle. This command not
        //only informs the SlotScheduler of the cycle start, but also
        //causes it to start slot-cycling.
        call ScheduleParams.setCycleStart(atFrame);
      }
    }
  }

  task void sleepToNextCycle(){
    error_t error;
    error = call SubCXRQ.requestSleep(0,
      lastCycleStart, 
      sched->slotLength*(sched->activeSlots) + 1);
    cdbg(SCHED, "stnc sleep lcs %lu %lu-%lu\r\n", 
      lastCycleStart,
      lastCycleStart + (sched->activeSlots)*sched->slotLength +1,
      lastCycleStart + sched->cycleLength);
    if (error == SUCCESS) {
      error = call SubCXRQ.requestWakeup(0,
        lastCycleStart,
        sched->cycleLength,
        call SkewCorrection.referenceFrame(masterId),
        call SkewCorrection.referenceTime(masterId),
        call SkewCorrection.getCorrection(masterId,
          sched->cycleLength));
      cdbg(SCHED, "req cw: %x\r\n",
        error);
    }else{
      cerror(SCHED, "req cycle sleep: %x\r\n",
       error);
    }
  }
  
  event void SlotNotify.lastSlot(){
    if (!scheduleReceived){
      missedCount++;
      cinfo(SCHED, "Missed %u\r\n", missedCount);
      lastCycleStart += sched->cycleLength;
      call ScheduleParams.setCycleStart(lastCycleStart);
    }else{
      scheduleReceived = FALSE;
      missedCount = 0;
    }
    if (missedCount < SCHEDULE_LOSS_THRESHOLD){
      post sleepToNextCycle();
    }else{
      //this should force the next RX to use MAX_WAIT.
      startSearch();
      cinfo(SCHED, "synch lost\r\n");
    }
  }

  event void SlotNotify.slotStarted(uint16_t sn){
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
      //TODO: why 2?
      error = call SubCXRQ.requestWakeup(0, 
        call SubCXRQ.nextFrame(FALSE), 2,
        INVALID_FRAME, INVALID_TIMESTAMP, 0);

    }
    if (error == SUCCESS){
      startDonePending = TRUE;
      state = S_SEARCH;
    }
  }

  async event void ActiveMessageAddress.changed(){ }
  event void StateDump.dumpRequested(){}
}
