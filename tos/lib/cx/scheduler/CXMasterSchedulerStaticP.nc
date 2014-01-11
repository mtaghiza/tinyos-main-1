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
 #include "CXLink.h"
module CXMasterSchedulerStaticP{
  provides interface SplitControl;
  provides interface CXRequestQueue;
  uses interface Boot;
  uses interface Random;
  
  uses interface SplitControl as SubSplitControl;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface Packet;
  uses interface CXPacketMetadata;

  //for addr
  uses interface CXLinkPacket;

  //for TTL
  uses interface CXNetworkPacket;

  uses interface SlotNotify;
  uses interface ScheduleParams;

  uses interface SkewCorrection;

  uses interface ScheduledAMSend;
  uses interface RoutingTable;

  uses interface ActiveMessageAddress;
  uses interface StateDump;
  uses interface RadioStateLog;
} implementation {
  message_t schedMsg_internal;
  message_t* schedMsg = &schedMsg_internal;
  cx_schedule_t* sched;

  message_t nextMsg_internal;
  message_t* nextMsg = &nextMsg_internal;
  cx_schedule_t* nextSched;
  bool scheduleUpdatePending = FALSE;
  bool startDonePending = FALSE;

  uint32_t lastSleep = INVALID_FRAME;

  uint32_t lastCycleStart = INVALID_FRAME;
  
  task void initializeSchedule(){
    call Packet.clear(schedMsg);
    sched = (cx_schedule_t*)(call ScheduledAMSend.getPayload(schedMsg,
      sizeof(cx_schedule_t)));
    sched -> sn = call Random.rand16() & 0xFF;
    sched -> cycleLength = CX_DEFAULT_CYCLE_LENGTH;
    sched -> slotLength = CX_DEFAULT_SLOT_LENGTH;
    sched -> activeSlots = (CX_ACTIVE_SLOTS_STATIC > CX_MAX_SLOTS)?  CX_MAX_SLOTS: CX_ACTIVE_SLOTS_STATIC;
    sched -> maxDepth = CX_DEFAULT_MAX_DEPTH;

    call RoutingTable.setDefault(sched->maxDepth);
  }

  event void Boot.booted(){
    post initializeSchedule();
  }

  void setNextSchedule(uint32_t cycleLength, uint32_t slotLength,
      uint8_t maxDepth){
    call Packet.clear(schedMsg);
    nextSched = call ScheduledAMSend.getPayload(nextMsg, 
      sizeof(cx_schedule_t));
    nextSched -> sn = sched->sn + 1;
    nextSched -> cycleLength = cycleLength;
    nextSched -> slotLength = slotLength;
    nextSched -> maxDepth = maxDepth;
    scheduleUpdatePending = TRUE;
  }

  task void initTask(){
    uint32_t refFrame = call SubCXRQ.nextFrame(FALSE);
    error_t error = call SubCXRQ.requestWakeup(0, refFrame, 1,
      call SkewCorrection.referenceFrame(call CXLinkPacket.addr()),
      call SkewCorrection.referenceTime(call CXLinkPacket.addr()), 
      0);

    if (SUCCESS == error){
      startDonePending = TRUE;
      //cool. we'll request sleep and next wakeup when the wakeup is handled
    }else{
      cerror(SCHED, "init.requestWakeup %x\r\n", error);
    }
  }

  event void SubCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    if (layerCount){
      signal CXRequestQueue.wakeupHandled(error, 
        layerCount, 
        atFrame, reqFrame);
    }else{
      if (startDonePending){
        startDonePending = FALSE;
        signal SplitControl.startDone(error);
      }
      if (SUCCESS == error){
        //we consider wake up to be at frame 0 of the cycle.
        uint32_t schedOF = 1;
        uint32_t lb = call RadioStateLog.dump();

        //log radio stats for the preceding idle period.
        if (lb){
          cinfo(RADIOSTATS, "LB %lu -1\r\n", lb);
          //indicate how long the idle period was.
          cinfo(RADIOSTATS, "LBI %lu %lu %lu\r\n", 
            lb, lastSleep, atFrame);
        }

        lastCycleStart = atFrame;
        //this is the start of the active period. We are master, so we
        //need to send out the schedule.
  
        //if we've made changes, now is the time to swap out the
        //  schedule.
        if (scheduleUpdatePending){
          message_t* swpM = schedMsg;
          cx_schedule_t* swpS = sched;
          schedMsg = nextMsg;
          sched = nextSched;
          nextMsg = swpM;
          nextSched = swpS;
          call RoutingTable.setDefault(sched->maxDepth);
        }
        //msg setup should happen when it goes through requestSend.
//        call CXSchedulerPacket.setScheduleNumber(schedMsg,
//          sched->sn);
//        call CXSchedulerPacket.setOriginFrame(schedMsg, 
//          schedOF + lastCycleStart);

        sched->cycleStartFrame = lastCycleStart;

        call CXPacketMetadata.setTSLoc(schedMsg, &(sched->timestamp));
        error = call ScheduledAMSend.send(AM_BROADCAST_ADDR,
          schedMsg, sizeof(cx_schedule_t),
          lastCycleStart + schedOF); 
        if (error != SUCCESS){
          cerror(SCHED, "Sched.reqS %x\r\n", error);
        }

        call ScheduleParams.setMasterId(call ActiveMessageAddress.amAddress());
        call ScheduleParams.setSchedule(sched);
        call ScheduleParams.setCycleStart(lastCycleStart);
        //TODO: this should be set somewhat dynamically.
        call ScheduleParams.setSlot(call ActiveMessageAddress.amAddress());
      }else{
        cerror(SCHED, "Sched.wh: %x\r\n", error);
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
        call SkewCorrection.referenceFrame(call CXLinkPacket.addr()),
        call SkewCorrection.referenceTime(call CXLinkPacket.addr()), 
        0);
      cdbg(SCHED, "req cw: %x \r\n",
        error);
    }else{
      cerror(SCHED, "req cycle sleep: %x\r\n",
       error);
    }
  }

  event void SlotNotify.lastSlot(){
    post sleepToNextCycle();
  }
  event void SlotNotify.slotStarted(uint16_t sn){
  }


  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    uint32_t subNext = call SubCXRQ.nextFrame(isTX);
    if (subNext == INVALID_FRAME){
      return INVALID_FRAME;
    }
    if (isTX){
      //we're always synched as master, so rely on slot scheduler to
      //figure out valid time.
      return subNext;
    } else {
      if (lastCycleStart != INVALID_FRAME && sched != NULL){
        //we have a schedule, so we can figure out when our sleep/wake
        //period is.
        uint32_t cycleSleep = lastCycleStart + (sched->slotLength)*(sched->activeSlots)+1;
        uint32_t cycleWake = lastCycleStart;
        while (cycleWake < subNext){
          cycleWake += sched->cycleLength;
        }

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
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    if (duration == 0){
      duration = RX_DEFAULT_WAIT;
    }
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
    if (layerCount){
      signal CXRequestQueue.receiveHandled(error, layerCount - 1, atFrame, reqFrame,
        didReceive, microRef, t32kRef, md, msg);
    }else{
      cerror(SCHED, "!Unexpected rx handled\r\n");
    }
  }
  
  // in addition to standard layerCount, we also set up the scheduler
  // header: schedule number = current schedule number, originFrame =
  // requested frame, translated to frames since start of cycle
  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){

    call CXSchedulerPacket.setScheduleNumber(msg, 
      sched->sn);
    call CXSchedulerPacket.setOriginFrame(schedMsg, 
      baseFrame + frameOffset - lastCycleStart);
    if (call CXNetworkPacket.getTTL(msg) == 0){
      call CXNetworkPacket.setTTL(msg, sched->maxDepth);
    }
    call CXLinkPacket.setSource(msg, call ActiveMessageAddress.amAddress());
    return call SubCXRQ.requestSend(layerCount + 1, 
      baseFrame, frameOffset, 
      txPriority,
      useMicro, microRef, 
      md, msg);
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
      cerror(SCHED, "master unexpected SH\r\n");
    }
  }

  event void ScheduledAMSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS == error){
//      cinfo(SCHED, "TX sched of %lu ts %lu ofs%lu\r\n",
//        call CXNetworkPacket.getOriginFrameNumber(schedMsg),
//        sched->timestamp,
//        call CXNetworkPacket.getOriginFrameStart(schedMsg));
      cinfo(SCHED, "SCHED TX %u %u %u %lu %lu\r\n",
        sched->sn,
        call ActiveMessageAddress.amAddress(),
        call CXNetworkPacket.getSn(msg),
        sched->cycleStartFrame,
        sched->cycleStartFrame);
      call SkewCorrection.addMeasurement(
        call CXLinkPacket.addr(),
        TRUE,
        call CXNetworkPacket.getOriginFrameStart(schedMsg),
        call CXNetworkPacket.getOriginFrameNumber(schedMsg),
        call CXNetworkPacket.getOriginFrameStart(schedMsg));
      //cool. schedule sent.
    }else{
      cerror(SCHED, "!CXMS.SD %x\r\n", error);
      //TODO: handle schedule troubles
    }
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
      if (SUCCESS == error){
        uint32_t lb = call RadioStateLog.dump();
        lastSleep = atFrame;
        if (lb && sched != NULL){
          cinfo(RADIOSTATS, "LB %lu %u\r\n",
            lb, sched->activeSlots);
        }
      }else{
        cerror(SCHED, "!sched.sh: %x\r\n", error);
      }
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, uint32_t refFrame, uint32_t refTime, int32_t correction){
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame,
    frameOffset, refFrame, refTime, correction);
  }


  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      startDonePending = TRUE;
      sched = (cx_schedule_t*)call ScheduledAMSend.getPayload(schedMsg, sizeof(cx_schedule_t));
      post initTask();
    }else{
      signal SplitControl.startDone(error);
    }
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event void ActiveMessageAddress.changed(){}
  event void StateDump.dumpRequested(){}
}
