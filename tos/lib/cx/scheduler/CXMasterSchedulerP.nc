
 #include "CXScheduler.h"
 #include "CXSchedulerDebug.h"
module CXMasterSchedulerP{
  provides interface SplitControl;
  provides interface CXRequestQueue;
  uses interface Boot;
  uses interface Random;
  
  uses interface SplitControl as SubSplitControl;
  uses interface CXRequestQueue as SubCXRQ;

  uses interface CXSchedulerPacket;
  uses interface Packet;

  //for addr
  uses interface CXLinkPacket;

  //for TTL
  uses interface CXNetworkPacket;

  uses interface SlotNotify;
  uses interface ScheduleParams;
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
  
  event void Boot.booted(){
    sched = (cx_schedule_t*)(call Packet.getPayload(schedMsg,
      sizeof(cx_schedule_t)));
    sched -> sn = call Random.rand16() & 0xFF;
    sched -> cycleLength = CX_DEFAULT_CYCLE_LENGTH;
    sched -> slotLength = CX_DEFAULT_SLOT_LENGTH;
    sched -> activeSlots = 4;
    sched -> maxDepth = CX_DEFAULT_MAX_DEPTH;
    sched -> numAssigned = 1;
    sched -> slotAssignments[0] = call CXLinkPacket.addr();
  }

  void setNextSchedule(uint32_t cycleLength, uint32_t slotLength,
      uint8_t maxDepth){
    nextSched = call Packet.getPayload(nextMsg, 
      sizeof(cx_schedule_t));
    nextSched -> sn = sched->sn + 1;
    nextSched -> cycleLength = cycleLength;
    nextSched -> slotLength = slotLength;
    nextSched -> maxDepth = maxDepth;
    scheduleUpdatePending = TRUE;
  }

  task void initTask(){
    uint32_t refFrame = call SubCXRQ.nextFrame(FALSE);
    error_t error = call SubCXRQ.requestWakeup(0, refFrame, 1, 0, 0);
    if (SUCCESS == error){
      startDonePending = TRUE;
      //cool. we'll request sleep and next wakeup when the wakeup is handled
    }else{
      printf("init.requestWakeup %x\r\n", error);
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
        }
        //make sure that msg is set up correctly
        call CXSchedulerPacket.setScheduleNumber(schedMsg,
          sched->sn);
        call CXSchedulerPacket.setOriginFrame(schedMsg, 
          schedOF + lastCycleStart);
//        printf("Setting PL to [%u]\r\n", sizeof(cx_schedule_t));
        call Packet.setPayloadLength(schedMsg, 
          sizeof(cx_schedule_t));
//        printf("Verify PL [%u]\r\n", 
//          call Packet.payloadLength(schedMsg));
        call CXNetworkPacket.setTTL(schedMsg, sched->maxDepth);
        call CXLinkPacket.setSource(schedMsg, 
          call CXLinkPacket.addr());

        sched->padding0 = 0x10;
        sched->padding1 = 0x11;
        sched->padding2 = 0x12;
        sched->padding3 = 0x13;
        sched->padding4 = 0x14;
        sched->padding5 = 0x15;
        sched->cycleStartFrame = lastCycleStart;
        error = call SubCXRQ.requestSend(0,
          lastCycleStart, schedOF,
          FALSE, 0,
          &(sched->timestamp),
          NULL, schedMsg);
        if (error != SUCCESS){
          printf("Sched.reqS %x\r\n", error);
        }

        call ScheduleParams.setSchedule(sched);
        call ScheduleParams.setCycleStart(lastCycleStart);
        //TODO: this should be set somewhat dynamically.
        call ScheduleParams.setSlot(TOS_NODE_ID);
      }else{
        printf("Sched.wh: %x\r\n", error);
      }
    }
  }

  task void sleepToNextCycle(){
    error_t error;
    error = call SubCXRQ.requestSleep(0,
      lastCycleStart, 
      sched->slotLength*(sched->activeSlots) + 1);
    printf_SCHED("stnc sleep lcs %lu %lu-%lu\r\n", 
      lastCycleStart,
      lastCycleStart + (sched->activeSlots)*sched->slotLength +1,
      lastCycleStart + sched->cycleLength);
    if (error == SUCCESS) {
      //TODO: apply skew correction
      error = call SubCXRQ.requestWakeup(0,
        lastCycleStart,
        sched->cycleLength,
        0, 0);
      printf_SCHED("req cw: %x \r\n",
        error);
    }else{
      printf("req cycle sleep: %x\r\n",
       error);
    }
  }

  event void SlotNotify.lastSlot(){
    post sleepToNextCycle();
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
      printf("Unexpected rx handled\r\n");
    }
  }
  
  // in addition to standard layerCount, we also set up the scheduler
  // header: schedule number = current schedule number, originFrame =
  // requested frame, translated to frames since start of cycle
  command error_t CXRequestQueue.requestSend(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef, 
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){

    call CXSchedulerPacket.setScheduleNumber(msg, 
      call CXSchedulerPacket.getScheduleNumber(schedMsg));
    call CXSchedulerPacket.setOriginFrame(schedMsg, 
      baseFrame + frameOffset - lastCycleStart);
    call CXNetworkPacket.setTTL(msg, sched->maxDepth);
    call CXLinkPacket.setSource(msg, TOS_NODE_ID);
    return call SubCXRQ.requestSend(layerCount + 1, 
      baseFrame, frameOffset, 
      useMicro, microRef, 
      tsLoc, 
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
      if (SUCCESS == error){
        printf("TX sched\r\n");
        //cool. schedule sent.
      }else{
        printf("SH %x\r\n", error);
        //TODO: handle schedule troubles
      }
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
        lastSleep = atFrame;
      }else{
        printf("sched.sh: %x\r\n", error);
      }
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, uint32_t t32kRef, int32_t correction){
    return call SubCXRQ.requestWakeup(layerCount + 1, baseFrame,
    frameOffset, t32kRef, correction);
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
      sched = (cx_schedule_t*)call Packet.getPayload(schedMsg, sizeof(cx_schedule_t));
      post initTask();
    }else{
      signal SplitControl.startDone(error);
    }
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
}
