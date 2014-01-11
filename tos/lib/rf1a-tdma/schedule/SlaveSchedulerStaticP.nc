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

 #include "schedule.h"
module SlaveSchedulerStaticP {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface Receive as AnnounceReceive;
  uses interface AMSend as RequestSend;
  uses interface Receive as ResponseReceive;
  uses interface PacketAcknowledgements;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface CXPacketMetadata;
  uses interface CXPacket;
  uses interface Random;

  uses interface AMPacket;
  uses interface CXRoutingTable;

  provides interface SlotStarted;

  provides interface ScheduledSend as RequestScheduledSend;
  provides interface ScheduledSend as DefaultScheduledSend;

} implementation {
  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

 
  cx_schedule_t* schedule = NULL;
  uint8_t scheduleNum = INVALID_SCHEDULE_NUM;

  uint16_t firstIdleFrame = 0;
  uint16_t lastIdleFrame = 0;
  uint16_t mySlot = INVALID_SLOT;
  bool hasSchedule = FALSE;
  bool softSynch = FALSE;
  bool claimedLast = FALSE;
  bool hasStarted = FALSE;
  bool inactiveSlot = FALSE;

  uint16_t curSlot = INVALID_SLOT;
  uint16_t curFrame = INVALID_SLOT;

  uint8_t cyclesSinceSchedule = 0;
  uint16_t framesSinceSynch = 0;

  #if CX_ENABLE_SKEW_CORRECTION == 1
  int32_t lag_per_cycle;
  bool firstLag = TRUE;
  #endif
  uint32_t last_root;
  uint32_t last_leaf;
  int32_t lag_per_slot = 0;


  enum {
    S_OFF = 0x00,
    S_LISTEN = 0x01,
    S_READY = 0x02,
  }; 

  uint8_t state = S_OFF;

  uint16_t getSlot(uint16_t frameNum);

  task void startDoneTask();
  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  task void startListen(){
    printf_SCHED_RXTX("start listen\r\n");
    state = S_LISTEN;
    softSynch = FALSE;
    hasSchedule = FALSE;
    mySlot = INVALID_SLOT;
    #if CX_ENABLE_SKEW_CORRECTION == 1
    last_leaf = 0;
    last_root = 0;
    lag_per_slot = 0;
    firstLag = TRUE;
    //maybe?
    schedule = NULL;
    #endif
    call TDMAPhySchedule.setSchedule(call TDMAPhySchedule.getNow(),
      0, 
      1, 
      SCHED_INIT_SYMBOLRATE,
      TEST_CHANNEL,
      hasSchedule, 
      FALSE
      );
  }

  uint8_t getSymbolRate(cx_schedule_t* sched){
    return SCHED_INIT_SYMBOLRATE;
  }
  uint8_t getChannel(cx_schedule_t* sched){
    return TEST_CHANNEL;
  }
  uint16_t getSlots(cx_schedule_t* sched){
    return SCHED_NUM_SLOTS;
  }
  uint16_t getFramesPerSlot(cx_schedule_t* sched){
    return SCHED_FRAMES_PER_SLOT;
  }
  uint8_t getMaxRetransmit(cx_schedule_t* sched){
    return SCHED_MAX_RETRANSMIT;
  }
  uint16_t getFirstIdleSlot(cx_schedule_t* sched){
    return STATIC_FIRST_IDLE_SLOT;
  }
  uint16_t getLastIdleSlot(cx_schedule_t* sched){
    return (SCHED_NUM_SLOTS - 1);
  }

  task void updateSchedule(){
    uint32_t cur_root;
    uint32_t cur_leaf;
    uint32_t startTS;
    uint16_t startFN;
    uint8_t sri = srIndex(getSymbolRate(schedule));
    softSynch = TRUE;
    hasSchedule = TRUE;
    scheduleNum = schedule->scheduleNum;
    //clock skew correction:
    // - we have originalFrameStartEstimate (local) and packet timestamp, 
    //   so use these as reference points
    // - just get the average delta per slot (in ticks) and adjust by this at each
    //   slot start: do this by issuing a setSchedule that uses
    //     (originalFrameStartEstimate + (slotNum*delta_per_slot),
    //      originalFrameNum + (slotNum* framesPerSlot))
    //OFN 0 and receivedCount 1: should be received at
    //frame 0, not frame 1. 

    //lag_per_cycle: (ts_1 - ts_0) - (ofse_1 - ofse_0) 
    //lag_per_slot: lag_per_cycle/numSlots
    cur_root = call CXPacket.getTimestamp(schedule_msg);
    cur_leaf = call CXPacketMetadata.getOriginalFrameStartEstimate(schedule_msg);
    #if CX_ENABLE_SKEW_CORRECTION == 1
    if (last_root != 0 && last_leaf != 0){
      int32_t dr = cur_root - last_root;
      int32_t dl = cur_leaf - last_leaf;
      int32_t lag = dr - dl;
      if (firstLag){
        firstLag = FALSE;
        lag_per_cycle = lag;
//        printf_TMP("LAGINIT %ld\r\n", 
//          lag);
      }else{
        int32_t lpc3 = (lag_per_cycle * 3);
        int32_t lpcp4 = lpc3 + lag;
        int32_t lpc = lpcp4 >> 2;
//        printf_TMP("LAGUP %ld: %ld -> %ld\r\n", 
//          lag, lag_per_cycle, lpc);
        lag_per_cycle = lpc;
      }
      lag_per_slot = lag_per_cycle / getSlots(schedule);
    }
    #else
    lag_per_slot = 0;
    #endif

    last_root = cur_root;
    last_leaf = cur_leaf;
    //We don't have this yet if we haven't done a synch.
    if (! cur_leaf){
      startTS = call CXPacketMetadata.getPhyTimestamp(schedule_msg) -
        sfdDelays[sri] - fsDelays[sri];
      startFN = call CXPacket.getOriginalFrameNum(schedule_msg) + call CXPacketMetadata.getReceivedCount(schedule_msg) -1;
    }else{
      startTS = cur_leaf;
      startFN = call CXPacket.getOriginalFrameNum(schedule_msg);
    }

//    printf_TMP("SS: %lu %u %u %u %u %x %x\r\n",
//      startTS,
//      startFN,
//      schedule->framesPerSlot*schedule->slots,
//      schedule->symbolRate,
//      schedule->channel,
//      hasSchedule,
//      (lag_per_slot != 0));

    //TODO: use CX_SKEW_ENABLED ( + some sort of skew correction
    //  applied)
    //TODO: actually use the skew calculation to set startTS correctly
    //(currently it's just using the timestamp obtained at reception)
    call TDMAPhySchedule.setSchedule(
      startTS,
      startFN,
      getFramesPerSlot(schedule)* getSlots(schedule),
      getSymbolRate(schedule),
      getChannel(schedule),
      hasSchedule,
      CX_ENABLE_SKEW_CORRECTION
    );
//    printf_TMP("updated\r\n");
    framesSinceSynch = 0;
    firstIdleFrame = (getFirstIdleSlot(schedule)  * 
      getFramesPerSlot(schedule));
    lastIdleFrame = (getLastIdleSlot(schedule) * getFramesPerSlot(schedule));
    if (state == S_LISTEN){
      state = S_READY;
      post startDoneTask();
    }
    mySlot = TOS_NODE_ID;
  }

  event message_t* AnnounceReceive.receive(message_t* msg, void* pl, uint8_t len){
    message_t* ret = schedule_msg;
    schedule_msg = msg;
    //make sure that root -> self distance retained.
    call CXRoutingTable.setPinned(call AMPacket.source(msg),
      TOS_NODE_ID, TRUE, TRUE);
    schedule = (cx_schedule_t*)pl;
//    printf_TMP("ar.r\r\n");
    post updateSchedule();
    cyclesSinceSchedule = 0;
    if (! hasSchedule){
      printf_SCHED_RXTX("SCHED_SYNCH\r\n");
    }
    return ret;
  }

  event void SubSplitControl.startDone(error_t error){ 
    printf_SCHED_RXTX("SCHED_SEARCH\r\n");
    post startListen();
  }

  event void SubSplitControl.stopDone(error_t error){ 
    hasStarted = FALSE;
    signal SplitControl.stopDone(error);
  }

  event void FrameStarted.frameStarted(uint16_t frameNum){
    uint32_t framesThisSlot = (frameNum % call TDMARoutingSchedule.framesPerSlot());
    bool newSlot = (0 == framesThisSlot);
    curFrame = frameNum;
    framesSinceSynch++;

    //if we are more than maxDepth frames into the slot, and the last
    //  synch occurred in a preceding slot, we can assume this slot is
    //  idle and go inactive.
    if (hasSchedule
        && ! newSlot 
        && framesThisSlot > call TDMARoutingSchedule.maxDepth()
        && framesSinceSynch > framesThisSlot 
        && ! (call TDMARoutingSchedule.ownsFrame(curFrame))){
      call TDMARoutingSchedule.inactiveSlot();
    }
    
    //increment the number of cycles since we last got a schedule
    //  announcement at the start of each cycle.
    if (frameNum == 0){
      cyclesSinceSchedule ++;
      if (cyclesSinceSchedule > CX_RESYNCH_CYCLES && state != S_LISTEN){
        printf_SCHED_RXTX("SYNCH_LOSS\r\n");
        hasSchedule = FALSE;
        post startListen();
      }
    }


    if (newSlot){
      if (hasSchedule){
        if (curSlot == 0 || VERBOSE_DUTY_CYCLE == 1){
          call TDMAPhySchedule.logDutyCycle(curSlot);
        }
      }
      curSlot = getSlot(frameNum);
      inactiveSlot = FALSE;
    }

    //TODO: this assumes that the schedule is always in slot 0
    //If we haven't gotten schedule yet this cycle, stay unsynched.
    if ((curSlot > 0) 
        && (softSynch && (framesSinceSynch > frameNum))){
      softSynch = FALSE;
      printf_SCHED_RXTX("SOFT_SYNCH_LOSS\r\n");
    }

    if (framesThisSlot == (call TDMARoutingSchedule.framesPerSlot() -1)){
      // re-synch to estimated root schedule 
      //issue a setSchedule that uses
      //  (originalFrameStartEstimate - (slotNum*lag_per_slot),
      //   originalFrameNum + (slotNum* framesPerSlot))
      //e.g. if we typically lag, then we need to bump up our start
      //     time
      if (schedule != NULL && last_leaf != 0){
//        uint32_t noMissTS = last_leaf 
//          + ((frameNum -1)*(call TDMAPhySchedule.getFrameLen())) 
//          - ((curSlot+1)*lag_per_slot);
        uint32_t wrapTS;
        uint16_t elapsedFrames = frameNum;
//        int32_t lps = lag_per_slot;
        //TODO: testing whether this is what I saw as bad clock skew
        //correction
        int32_t lps = 0;
        elapsedFrames += cyclesSinceSchedule*(
          getFramesPerSlot(schedule)*getSlots(schedule));
        //target frame start is last reception...
        wrapTS = last_leaf;
        //...plus the duration of elapsed frames
        wrapTS += ((elapsedFrames )*(call TDMAPhySchedule.getFrameLen()));
        //...minus the lag introduced for each elapsed slot
        wrapTS -= ((curSlot+1 + (cyclesSinceSchedule*getSlots(schedule)))*lps);
//        printf_TMP("NMT %lu css %u WT %lu\r\n", 
//          noMissTS,
//          cyclesSinceSchedule, wrapTS);
        call TDMAPhySchedule.adjustFrameStart(
          wrapTS,
          frameNum);
      }
    }

    if (newSlot){
      signal SlotStarted.slotStarted(curSlot);
    }
  }

  event void RequestSend.sendDone(message_t* msg, error_t error){
  }

  task void startDoneTask(){
    if (!hasStarted){
      hasStarted = TRUE;
      signal SplitControl.startDone(SUCCESS);
    }
  }

  event message_t* ResponseReceive.receive(message_t* msg, void* pl, uint8_t len){
    return msg;
  }

  //(ALL)
  // AnnounceReceive / TDMAPhySchedule.set

  //S_OFF
  // start / TDMAPhySchedule.listen
  // -> S_LISTEN

  //S_LISTEN
  // AnnounceReceive / TDMAPhySchedule.set, soft-claim a slot, call
  //   RequestSend
  // -> S_REQUESTING
  
  //S_REQUESTING: soft ownership claimed over a slot (send request in it)
  // RequestSend.sendDone / -
  // -> S_CONFIRM_WAIT

  //S_CONFIRM_WAIT: do not assert ownership over any frames
  // ResponseReceive.receive OR AnnounceReceive indicating its claimed
  // OR timeout / -
  // -> S_LISTEN

  event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
      return CX_DUTY_CYCLE_ENABLED 
        && (inactiveSlot || ((state != S_LISTEN) && (schedule != NULL) 
        && (frameNum > firstIdleFrame && frameNum < lastIdleFrame)));
  }

  command error_t TDMARoutingSchedule.inactiveSlot(){
    inactiveSlot = TRUE;
    return SUCCESS;
  }

  event uint8_t TDMAPhySchedule.getScheduleNum(){
    return scheduleNum;
  }
  
  event void TDMAPhySchedule.resynched(uint16_t resynchFrame){
    if ( !softSynch){
      printf_SCHED_RXTX("FAST_RESYNCH\r\n");
      printf_TMP("#Fast resynch@ %u\r\n", resynchFrame);
      softSynch = TRUE;
    }
    framesSinceSynch = 0;
  }

  command bool TDMARoutingSchedule.isSynched(){
    return softSynch && hasSchedule;
  }
  
  command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return getFramesPerSlot(schedule);
  }

  //No retransmissions allowed if we're not in synch.
  command uint8_t TDMARoutingSchedule.maxRetransmit(){
    if (call TDMARoutingSchedule.isSynched()){
      return getMaxRetransmit(schedule);
    } else {
      return 0;
    }
  }
  uint16_t getSlot(uint16_t frameNum){
    return frameNum / call TDMARoutingSchedule.framesPerSlot();
  }
  command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    return getSlot(frameNum) == mySlot;
  }

  command uint16_t TDMARoutingSchedule.maxDepth(){
    //TODO: should this be in the schedule announcement?
    return SCHED_MAX_DEPTH;
  }

  command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return getFramesPerSlot(schedule) - (frameNum % getFramesPerSlot(schedule));
  }

  command uint16_t TDMARoutingSchedule.currentFrame(){
    return curFrame;
  }
  
  //Requests: ready if we're synched or it's the right slot.
  command uint16_t RequestScheduledSend.getSlot(){
    return mySlot;
  }

  command bool RequestScheduledSend.sendReady(){
    return call TDMARoutingSchedule.isSynched();
  }

  //everything else: ready if we're synched
  command uint16_t DefaultScheduledSend.getSlot(){
    return mySlot;
  }

  command bool DefaultScheduledSend.sendReady(){
    return (state == S_READY) && hasSchedule && softSynch;
  }

  command uint16_t TDMARoutingSchedule.getNumSlots(){
    return getSlots(schedule);
  }

  command uint16_t SlotStarted.currentSlot(){ 
    return curSlot;
  }
   
}

