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

 #include "SchedulerDebug.h"
 #include "schedule.h"
 #include "TimingConstants.h"
module NonRootSchedulerP{
  provides interface SplitControl;
  provides interface TDMARoutingSchedule;
  uses interface FrameStarted;

  uses interface SplitControl as SubSplitControl;
  uses interface TDMAPhySchedule;

  uses interface AMSend as AnnounceSend;
  uses interface Receive as AnnounceReceive;
  uses interface AMSend as ReplySend;
  uses interface Receive as ReplyReceive;

  uses interface Packet;
  uses interface CXPacket;
  uses interface Rf1aPacket;
  uses interface CXPacketMetadata;
  //maybe this should be done by Flood send.
  uses interface AMPacket;

  uses interface CXRoutingTable;
} implementation {
 
  //store current/next schedule as pointer to some received-schedule's
  //  payload.
  //This layer needs to have two message_t's then. When we receive a
  //  an announcement with a new schedule, we swap it with nextSched.
  //When we switch to a new schedule, we swap nextSched and curSched.
//  uint8_t scheduleCount = 0;

  message_t sched_1;
  message_t* curMsg = &sched_1;
  cx_schedule_t* curSched;
  const cx_schedule_descriptor_t* curSchedDescriptor =
    &SCHEDULES[TDMA_INIT_SCHEDULE_ID];

  message_t reply_msg_internal;
  message_t* replyMsg = &reply_msg_internal;

  uint16_t framesSinceLastSchedule = 2;
  uint16_t framesSinceLastSynch = 2;
  uint16_t lastRxFrameNum;
  uint32_t lastRxTS;
  uint32_t lastRootStart;
  uint32_t lastSR;
  bool isSynched = FALSE;

  int32_t ticksPerFrame;
  uint16_t extraFrames = 0;
  int32_t extraFrameOffset;
  int32_t endOfCycle;

  uint16_t cycleNum = 0;

  bool changePending;
  bool replyPending;
  bool startPending;

  #define DELTA_BUF_LEN 8
  int32_t delta[DELTA_BUF_LEN];

  command error_t SplitControl.start(){
    error_t error = call SubSplitControl.start();
    if (SUCCESS == error){
      startPending = TRUE;
    }
    return error;
  }

  error_t initSchedule(){
    curSched = (cx_schedule_t*)(call Packet.getPayload(curMsg, sizeof(cx_schedule_t)));
//    curSched -> frameLen = DEFAULT_TDMA_FRAME_LEN;
//    curSched -> fwCheckLen = DEFAULT_TDMA_FW_CHECK_LEN;
//    curSched -> activeFrames = TDMA_ROOT_ACTIVE_FRAMES;
//    curSched -> inactiveFrames = TDMA_ROOT_INACTIVE_FRAMES;
//    curSched -> symbolRate = TDMA_INIT_SYMBOLRATE;
//    curSched -> scheduleNum = 0xff;
//    curSched -> framesPerSlot = TDMA_ROOT_FRAMES_PER_SLOT;
//    curSched -> maxRetransmit = TDMA_MAX_RETRANSMIT;
//    curSched -> frameLen = 10*DEFAULT_TDMA_FRAME_LEN;
//    curSched -> fwCheckLen = 2*10*DEFAULT_TDMA_FRAME_LEN;
//    curSched -> activeFrames = 1;
//    curSched -> inactiveFrames = 0;
//    curSched -> framesPerSlot = 0;
//    curSched -> maxRetransmit = 0;
//    curSched -> channel = TEST_CHANNEL;
    curSched -> symbolRate = TDMA_INIT_SYMBOLRATE;
    curSched -> scheduleId = TDMA_INIT_SCHEDULE_ID;
    curSched -> scheduleNum = 0xff;
    curSchedDescriptor = &SCHEDULES[curSched->scheduleId];


    lastSR = curSched -> symbolRate;
    isSynched = FALSE;
    return call TDMAPhySchedule.setSchedule(
      call TDMAPhySchedule.getNow(), 
      0, 
      10*frameLens[srIndex(curSched->symbolRate)],
      2*10*frameLens[srIndex(curSched->symbolRate)],
      1,
      0,
      curSched->symbolRate,
      curSchedDescriptor->channel,
      FALSE);
  }

  task void initScheduleTask(){
    error_t error = initSchedule();
    if (SUCCESS != error){
      printf("initSchedule: %s\r\n", decodeError(error));
    }
  }

  //initialize curSched to try to catch a new schedule announcement.
  event void SubSplitControl.startDone(error_t error){
//    call AMPacket.clear(replyMsg);
    if (SUCCESS != error){
      printf("setSchedule: %s\r\n", decodeError(error));
    }else{
      printf_SCHED("ssc.sd setSchedule OK\r\n");
      error = initSchedule();
      if (SUCCESS != error){
        printf("initSchedule error: %s\r\n", decodeError(error));
      }
    }
  }

  task void printCur(){
    #if DEBUG_SCHED_SR == 1
    cx_schedule_t* pl = (cx_schedule_t*) call Packet.getPayload(curMsg, sizeof(cx_schedule_t));
    printf_SCHED_SR("ps %p (%p) sn %u of %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u chan %u\r\n", 
      curMsg, pl,
      pl->scheduleNum, pl->originalFrame, pl->frameLen,
      pl->fwCheckLen, pl->activeFrames, pl->inactiveFrames,
      pl->framesPerSlot, pl->maxRetransmit, pl->symbolRate,
      pl->channel);
    #endif
  }

  task void updateScheduleTask();


  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    cx_schedule_t* pl = (cx_schedule_t*) payload;
    uint32_t rxTS;
    uint32_t curRootStart;
    uint16_t rxFrameNum;
    printf_SCHED("AR.r ");
    printf_SCHED_RXTX("RX s: %u d: %u sn: %u c: %u r: %d l: %u\r\n", 
      call CXPacket.source(msg),
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      call CXPacketMetadata.getReceivedCount(msg),
      call Rf1aPacket.rssi(msg),
      call Rf1aPacket.lqi(msg));
  
    //update clock skew figures 
    framesSinceLastSchedule = 0;

    rxFrameNum = call CXPacket.getOriginalFrameNum(msg)
      + call CXPacketMetadata.getReceivedCount(msg)
      - 1;  
    rxTS = call CXPacketMetadata.getPhyTimestamp(msg);
    curRootStart = call CXPacket.getTimestamp(msg);

    if (pl->scheduleNum == curSched->scheduleNum){
      printf_SCHED("s");
      if(lastRxTS != 0){
        uint8_t i;
        uint32_t rootTicks;
        uint32_t myTicks;
        int32_t d;
        int32_t framesElapsed = 
          curSchedDescriptor->activeFrames+curSchedDescriptor->inactiveFrames;
        printf_SCHED("v");
        printf_SCHED("(%lu, %lu) -> (%lu, %lu) over %ld\r\n", 
          lastRxTS, lastRootStart, 
          rxTS, curRootStart,
          framesElapsed);
        rootTicks = curRootStart - lastRootStart;
        myTicks = rxTS - lastRxTS;
        d = myTicks - rootTicks;
        delta[(cycleNum)%DELTA_BUF_LEN] = d;
        cycleNum++;
        printf_SCHED(" %ld ", d);
        for (i = 0; i < DELTA_BUF_LEN; i++){
          d+=delta[i];
        }
        d = d/(cycleNum > DELTA_BUF_LEN ? DELTA_BUF_LEN : cycleNum);
        //TODO: double check this logic. 
        if ( d > framesElapsed ){
          //evenly distribute as much as possible
          ticksPerFrame = d/framesElapsed;
          //distribute leftovers over the rest of the frames as evenly
          //as possible. 
          d -= (ticksPerFrame*framesElapsed);
          if (d){
            extraFrames = framesElapsed/d;
            extraFrameOffset = 1;
            //If frameNum %extraFrames != 0, add another tick to the last
            //frame.
            endOfCycle = (framesElapsed % extraFrames)?1:0;
          }else{
            extraFrames = framesElapsed;
            extraFrameOffset = 0;
            endOfCycle = 0;
          }
        }else if ( d < -1*framesElapsed){
          //same but for negative ticks
          ticksPerFrame = -1* (d/framesElapsed);
          d -= (ticksPerFrame*framesElapsed);
          if (d){
            extraFrames = -1*(framesElapsed/d);
            extraFrameOffset = -1;
            endOfCycle = (framesElapsed % extraFrames)?-1:0;
          }else{
            extraFrames = framesElapsed;
            extraFrameOffset = 0;
            endOfCycle = 0;
          }
        }
      }else{
        printf_SCHED("~v");
      }
      lastRxTS = rxTS;
      lastRxFrameNum = rxFrameNum;
      lastRootStart = call CXPacket.getTimestamp(msg);
      printf_SCHED("\r\n");
      printf_TESTBED_SCHED_ALL("s %u\r\n", 
        call CXPacketMetadata.getReceivedCount(msg));
//      post updateScheduleTask();
      return msg; 
    } else {
      message_t* swp = curMsg;
      printf_SCHED("n\r\n");
      changePending = TRUE;
      lastRxTS = rxTS;
      lastRxFrameNum = rxFrameNum;
      lastRootStart = call CXPacket.getTimestamp(msg);
      extraFrames = 1;
      extraFrameOffset = 0;
      endOfCycle = 0;
      lastSR = curSched->symbolRate;

      curMsg = msg;
      curSched = (cx_schedule_t*)payload;
      curSchedDescriptor = &SCHEDULES[curSched->scheduleId];
      printf_TESTBED_SCHED_NEW("S %u\r\n", 
        call CXPacketMetadata.getReceivedCount(msg));
      printf_SCHED_SR("RX new: %p sn %u sr %u\r\n", curMsg,
        curSched->scheduleNum, curSched->symbolRate);
      post updateScheduleTask();
      post printCur();
      return swp;
    }
  }

  task void replyTask(){
    error_t error;
    cx_schedule_reply_t* reply = 
      (cx_schedule_reply_t*)call ReplySend.getPayload(replyMsg, sizeof(cx_schedule_reply_t));
    reply->scheduleNum = curSched->scheduleNum;
    //TODO: should be from source of schedule (root ID will frequently be non-0)
    error = call ReplySend.send(0, replyMsg, sizeof(replyMsg));
    if (SUCCESS == error){
      printf_SCHED_SR("ReplySend.send OK\r\n");
    }else{
      printf("ReplySend: %s\r\n", decodeError(error));
    }
  }

  task void updateScheduleTask(){
    error_t error;
    uint8_t lastSRI = srIndex(lastSR);
    printf_SCHED("UST");
//    printf_SCHED_SR("UST from %p\r\n", curSched);
    //account for propagation delays here.
    isSynched = TRUE;
    error = call TDMAPhySchedule.setSchedule(
      lastRxTS 
        - sfdDelays[lastSRI] 
        - fsDelays[lastSRI],
//        - tuningDelays[lastSRI], 
      lastRxFrameNum,
      frameLens[srIndex(curSched->symbolRate)],
      fwCheckLens[srIndex(curSched->symbolRate)],
      curSchedDescriptor->activeFrames,
      curSchedDescriptor->inactiveFrames, 
      curSched->symbolRate,
      curSchedDescriptor->channel,
      TRUE);

    if (changePending){
      lastRxTS = 0;
      lastRxFrameNum = 0;
      changePending = FALSE;
      replyPending = TRUE;
      post replyTask();
    }
    if (SUCCESS == error){
      printf_SCHED(" OK\r\n");

    }else{
      printf("NonRootSchedulerP.UST!%s", decodeError(error));
    }
  }
  
  task void resetRadioStack(){
    //TODO: reset internal state
    //TODO: call subsplitcontrol.stop()
  }


  async event void FrameStarted.frameStarted(uint16_t frameNum){
    bool lostSynch;
    bool lostSchedule;
    framesSinceLastSchedule++;
    framesSinceLastSynch++;

    //reinitialize the schedule if we have gone too long without
    //hearing it.
    //also: try to do this not-so-close to the very beginning of the
    //cycle, where we can get into all kinds of trouble/edge cases.
    lostSynch = framesSinceLastSynch >
        TDMA_TIMEOUT_CYCLES*(curSchedDescriptor->activeFrames) +
        curSchedDescriptor->activeFrames / 2 ;
    lostSchedule = framesSinceLastSchedule >
        2*TDMA_TIMEOUT_CYCLES*(curSchedDescriptor ->activeFrames) +
        curSchedDescriptor->activeFrames/2 ;

    if (isSynched && (lostSynch || lostSchedule)){
      isSynched = FALSE;
      printf_TESTBED("SYNCH LOST\r\n");
      printf_SCHED_SR("LOST SYNC\r\n");
      framesSinceLastSchedule = 0;
      framesSinceLastSynch = 0;
      //TODO: at this point, it would be safer/easier to just restart
      //the entire radio stack.
      //post resetRadioStack();
      post initScheduleTask();
    }
  }

  event void ReplySend.sendDone(message_t* msg, error_t error){
    printf_SCHED_RXTX("TX s: %u d: %u sn: %u rm: %u pr: %u e: %u\r\n",
      TOS_NODE_ID,
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      (call CXPacket.getNetworkProtocol(msg)) & ~CX_NP_PREROUTED,
      ((call CXPacket.getNetworkProtocol(msg)) & CX_NP_PREROUTED)?1:0,
      error);

    if (startPending){
      startPending = FALSE;
      signal SplitControl.startDone(SUCCESS);
    }    
    replyPending = FALSE;
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){
  }
  
  //ticksPerFrame: applied to each frame
  //if we're on an extraFrames boundary, add or subtract another one
  //if this is the last frame of the cycle, add in whatever's left.
  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){
    #if ENABLE_SKEW_CORRECTION == 0
    #warning Disabling skew correction
    return 0;
    #else
    return -1*(ticksPerFrame 
      + ((frameNum %extraFrames == 0)?extraFrameOffset:0)
      + ((frameNum == 
          (curSched->activeFrames + curSched->inactiveFrames -1))
          ? endOfCycle: 0));
    #endif
  }

  async event void TDMAPhySchedule.peek(message_t* msg, 
      uint16_t frameNum, uint32_t rxTime){
    uint16_t senderFrameNum = (call CXPacket.getOriginalFrameNum(msg) 
      + call CXPacketMetadata.getReceivedCount(msg) 
      - 1);
    if (call CXPacketMetadata.getFrameNum(msg) == senderFrameNum 
        && (call CXPacket.getScheduleNum(msg) 
          == signal TDMAPhySchedule.getScheduleNum())){
      framesSinceLastSynch = 0;
    } else {
      //TODO: if we are out of synch, but this schedule num matches
      //our current schedule num, then we should post a task to update
      //the schedule.
    }
  }

  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    return curSched->scheduleNum;
  }

//  //we are origin if reply needed and this is the start of our slot.
//  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
//    printf_SCHED_IO("io: ");
//    if ((rm == CX_NP_FLOOD) 
//        && replyPending 
//        && (frameNum == (TOS_NODE_ID * (curSchedDescriptor->framesPerSlot)))){
//      printf_SCHED_IO("T\r\n");
//      return TRUE;
//    }else{
//      printf_SCHED_IO("F\r\n");
//      return FALSE;
//    }
//  }

  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return isSynched;
  }

  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
//    printf_SCHED("nrs.mr\r\n");
    return curSchedDescriptor->maxRetransmit;
  }
  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return curSchedDescriptor->framesPerSlot;
  }
  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return call TDMARoutingSchedule.framesPerSlot() 
      - (frameNum % (call TDMARoutingSchedule.framesPerSlot()));
  }

  //TODO: replace with dynamic slot-assignment logic
  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    uint16_t firstFrame = (call TDMARoutingSchedule.framesPerSlot())*TOS_NODE_ID;
    uint16_t lastFrame = firstFrame 
      + call TDMARoutingSchedule.framesPerSlot() -1;
    return ((frameNum >= firstFrame) 
      && (frameNum <= lastFrame));
  }

  //unused
  event void AnnounceSend.sendDone(message_t* msg, error_t error){}
  event message_t* ReplyReceive.receive(message_t* msg, void* payload, uint8_t len){ return msg;}

  
}
