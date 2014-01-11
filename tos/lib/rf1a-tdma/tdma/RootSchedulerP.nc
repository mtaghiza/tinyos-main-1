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
 #include "SchedulerDebug.h"
 #include "TimingConstants.h"

module RootSchedulerP{
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
  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Rf1aPacket;
  uses interface CXRoutingTable;
  uses interface CXPacketMetadata;
  //maybe this should be done by Flood send.
} implementation {

  enum {
    S_OFF            = 0x00,
    S_SC_STARTING    = 0x01,

    S_BASELINE       = 0x02,
    S_ADJUSTING      = 0x03,
    S_CHECKING       = 0x04,
    S_FINALIZING     = 0x05,
    S_FINAL_CHECKING = 0x06,
    S_ESTABLISHED    = 0x07,

//    S_RESET_STOPPING,
//    S_RESET_STOPPED,
//    S_RESET_STARTING,
    S_RESETTING      = 0x08,

  };

  enum {
    S_NOT_SENT = 0x00,
    S_SENDING  = 0x01,
    S_WAITING  = 0x02,
  };

  enum {
    S_UNKNOWN    = 0x00,
    S_DISCOVERED = 0x01,
  };

  enum{
    S_SET            = 0x00,
    S_SWITCH_PENDING = 0x01,
  };
  
  task void announceSchedule();
  task void printSchedule();

  //transition test functions
  bool disconnected();
  bool higherSRChecked();
  bool lowerMoreEfficient();
  bool maxSRKnown();

  //schedule announcement modification functions
  void resetNextSR(bool resetC, bool resetM);
  bool increaseNextSR();
  bool decreaseNextSR();
  void finalizeNextSR();
  void keepNextSR(bool increaseSN);
  void setupPacket(message_t* msg, 
      uint8_t sn, 
      uint8_t symbolRate, 
      uint8_t scheduleId);

  //schedule modification functions
  void initializeSchedule();
  task void updateScheduleTask();
  void useNextSchedule();

  uint8_t totalNodes = TDMA_MAX_NODES - 1;

  uint8_t state = S_OFF;
  uint8_t txState = S_NOT_SENT;
  uint8_t srState = S_UNKNOWN;
  uint8_t psState = S_SWITCH_PENDING;
  uint8_t lastSR = 0;
  uint8_t curSR = 0;
  uint8_t nextSR = 0;
  uint8_t maxSR = 0;
  uint8_t nextBLSN = 0;
  bool resetBL = TRUE;
  bool blPending = FALSE;

  uint16_t nodesReachable[NUM_SRS]; 
  uint8_t maxDepth[NUM_SRS]; 
  message_t cur_schedule_msg_internal;
  message_t* cur_schedule_msg = &cur_schedule_msg_internal;
  cx_schedule_t* curSchedule;
  const cx_schedule_descriptor_t* curScheduleDescriptor;

  message_t next_schedule_msg_internal;
  message_t* next_schedule_msg = &next_schedule_msg_internal;
  cx_schedule_t* nextSchedule;

  void reset();
  void useNextSchedule();

  command error_t SplitControl.start(){
    error_t error;
    if (state == S_OFF){
      error = call SubSplitControl.start();
      if (SUCCESS == error){
        printf_SCHED("SSC.s\r\n");
        state = S_SC_STARTING;
      }
    }
    return error;
  }

  event void SubSplitControl.startDone(error_t error){
    printf_SCHED("ssc.sd\r\n");
    if (state == S_SC_STARTING){
      if (SUCCESS == error){
        initializeSchedule();
        state = S_BASELINE;
        post announceSchedule();
      } else {
        printf("SSC.sd error %s\r\n", decodeError(error));
      }
      signal SplitControl.startDone(error);
    } else {
      printf("unexpected state %x at ssc.startdone\r\n", state);
    }
  }

  //we always announce the *next* schedule. In the steady-state, next
  //and current have the same contents.
  task void announceSchedule(){
    if (state == S_BASELINE || state == S_ADJUSTING 
        || state == S_FINALIZING || state == S_RESETTING 
        || state == S_ESTABLISHED){
      error_t error;
      error = call AnnounceSend.send(AM_BROADCAST_ADDR, 
        next_schedule_msg,
        sizeof(cx_schedule_t)); 
      if (SUCCESS == error){
        cx_schedule_t* ns = (cx_schedule_t*)(call
          Packet.getPayload(next_schedule_msg,
          sizeof(cx_schedule_t)));
        printf_SCHED("Announce Sending %p sn %u sr %u\r\n", 
          next_schedule_msg,
          ns->scheduleNum,
          ns->symbolRate);
        txState = S_SENDING;
      }else if (EBUSY == error){
        printf_SCHED("announce schedule: %s\r\n", decodeError(error));
      }else {
        printf("announce schedule: %s\r\n", decodeError(error));
      }
    } else {
      printf("unexpected state %x in announceSchedule\r\n", state);
    }
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS != error){
      printf("AS.send done: %s\r\n", decodeError(error));
    } else {
      printf_SCHED_RXTX("TX s: %u d: %u sn: %u rm: %u pr: %u e: %u\r\n",
        TOS_NODE_ID,
        call CXPacket.destination(msg),
        call CXPacket.sn(msg),
        (call CXPacket.getNetworkProtocol(msg)) & ~CX_NP_PREROUTED,
        ((call CXPacket.getNetworkProtocol(msg)) & CX_NP_PREROUTED)?1:0,
        error);

      if (state == S_BASELINE || state == S_ADJUSTING 
          || state == S_FINALIZING || state == S_RESETTING
          || state == S_ESTABLISHED){
        txState = S_WAITING;
        if (state == S_BASELINE){
          //no change, but need to update schedule num.
          useNextSchedule();
        } else if (state == S_ADJUSTING){
          state = S_CHECKING;
          useNextSchedule();
        } else if (state == S_FINALIZING){
          state = S_FINAL_CHECKING;
          useNextSchedule();
        } else if (state == S_RESETTING){
          state = S_BASELINE;
          useNextSchedule();
        }
        //ESTABLISHED: no change.
        printf_TIMING("sched %lu sfd %lu sfd-sched %lu \r\n", 
          call CXPacket.getTimestamp(msg), 
          call CXPacketMetadata.getPhyTimestamp(msg), 
          call CXPacketMetadata.getPhyTimestamp(msg) - call CXPacket.getTimestamp(msg)
        );
//        printf_TIMING("sched %lu sfd %lu handled %lu sfd-sched %lu sched-handled %lu sfd-handled %lu\r\n", 
//          call CXPacket.getTimestamp(msg), 
//          call CXPacketMetadata.getPhyTimestamp(msg), 
//          call CXPacketMetadata.getAlarmTimestamp(msg),
//          call CXPacketMetadata.getPhyTimestamp(msg) - call CXPacket.getTimestamp(msg),
//          call CXPacketMetadata.getAlarmTimestamp(msg) - call CXPacket.getTimestamp(msg),
//          call CXPacketMetadata.getPhyTimestamp(msg) - call CXPacketMetadata.getAlarmTimestamp(msg)
//        );
      } else {
        printf_SCHED("Unexpected state %x in as.sendDone\r\n", state);
      }
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){

    if ((1+frameNum)%(curScheduleDescriptor->activeFrames +
    curScheduleDescriptor->inactiveFrames) == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      txState = S_NOT_SENT;
      #if CX_ADAPTIVE_SR != 1
      state = S_ESTABLISHED;
      #endif
      if (state != S_ESTABLISHED){
        printf_SCHED_SR("fs");
      }

      //BASELINE: 
      // - disconnected: stay in baseline until everybody shows up
      //   (BASELINE)
      // - connected:
      //   - sr discovered: announce it (FINALIZING)
      //   - sr unknown: baseline +1 and announce (ADJUSTING)
      if (state == S_BASELINE){
        printf_SCHED_SR("b");
        if (disconnected()){
          printf_SCHED_SR("d");
          keepNextSR(TRUE);
        }else {
          if (maxSRKnown()){
            printf_SCHED_SR("f");
            state = S_FINALIZING;
            finalizeNextSR();
          } else {
            if (increaseNextSR()){
              printf_SCHED_SR("^");
              state = S_ADJUSTING;
            } else {
              printf_SCHED_SR("=");
              state = S_ESTABLISHED;
              keepNextSR(FALSE);
            }
          }
        }

      //CHECKING: look at replies from last round and adjust, reset,
      //or stand pat depending on result.
      } else if (state == S_CHECKING){
        printf_SCHED_SR("c");
        // - disconnected: last used is max SR, sr discovered, go back
        //   to baseline and wait for everybody. (BASELINE)
        if (disconnected()){
          printf_SCHED_SR("d");
          maxSR = lastSR;
          srState = S_DISCOVERED;
          state = S_RESETTING;
          resetNextSR(TRUE, FALSE);

        // - connected, but last setting was more efficient: adjust
        //   next schedule and announce it (FINALIZING) 
        } else if (lowerMoreEfficient()){
          printf_SCHED_SR("V");
          decreaseNextSR();
          maxSR = nextSR;
          srState = S_DISCOVERED;
          state = S_FINALIZING;

        // - higher sr is also connected, but not as efficient
        //   (ESTABLISHED)
        } else if (higherSRChecked()){
          printf_SCHED_SR("=");
          srState = S_DISCOVERED;
          maxSR = curSR;
          keepNextSR(FALSE);
          state = S_ESTABLISHED;

        // - next sr up may be more efficient, so try it (ADJUSTING)
        } else {
          printf_SCHED_SR("^");
          increaseNextSR();
          state = S_ADJUSTING;
        }

      //FINAL_CHECKING: we were all synched up, then announced a new
      //symbol rate (which we intend to keep as the final SR). 
      } else if (state == S_FINAL_CHECKING){
        printf_SCHED_SR("C");
        // - got all the replies we expected, so call it quits.
        //   (ESTABLISHED)
        if (!disconnected()){
          printf_SCHED_SR("=");
          keepNextSR(FALSE);
          state = S_ESTABLISHED;

        //Disconnected, so try it again from the top :( (BASELINE)
        } else {
          printf_SCHED_SR("d!");
          state = S_RESETTING;
          resetNextSR(TRUE, TRUE);
        }

      //ESTABLISHED: keep same symbol rate, don't change schedule
      //  number.
      } else if (state == S_ESTABLISHED){
        printf_SCHED_SR("=");
        keepNextSR(FALSE);
      }
      printf_SCHED_SR("\r\n");
      post announceSchedule();
    }
  }

  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){
    //as root, we let the rest of the network adjust around us.
    return 0;
  }

  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return curScheduleDescriptor->framesPerSlot;
  }

  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    //TODO: this should be flexible enough to allow root to have
    //multiple slots.
    return (frameNum <= call TDMARoutingSchedule.framesPerSlot());
  }
  
//  //as root: we are origin for floods during frame 0. Other frames?
//  //defer to AODV.
//  async command bool TDMARoutingSchedule.isOrigin(uint16_t frameNum){
//    //TODO: router gets slot 0, and should also be allowed at least
//    //one other one (or just any unassigned slots.)
//    if (frameNum == 0){ //&& rm == CX_NP_FLOOD){
//      return TRUE;
//    }else {
//      return FALSE;
//    }
//  }
  
  //always in synch, so ok to forward.
  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return TRUE;
  }

  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return curScheduleDescriptor->maxRetransmit;
  }

  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return call TDMARoutingSchedule.framesPerSlot() 
      - (frameNum % (call TDMARoutingSchedule.framesPerSlot()));
  }
  
  am_addr_t rrSource;
  am_addr_t rrDest;
  uint32_t rrSn;
  uint8_t rrRC;
  int16_t rrRssi;
  uint8_t rrLqi;

  task void reportReplyReceive(){
    printf_SCHED_RXTX("RX s: %u d: %u sn: %lu c: %u r: %d l: %u\r\n", 
      rrSource,
      rrDest,
      rrSn,
      rrRC,
      rrRssi,
      rrLqi);
  }

  event message_t* ReplyReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    uint8_t curSRI; 
    uint8_t receivedCount = call CXPacketMetadata.getReceivedCount(msg);
    cx_schedule_reply_t* reply = (cx_schedule_reply_t*)payload;
    curSRI = srIndex(curSchedule->symbolRate);    
    rrSource = call CXPacket.source(msg);
    rrDest = call CXPacket.destination(msg);
    rrSn = call CXPacket.sn(msg);
    rrRC = call CXPacketMetadata.getReceivedCount(msg);
    rrRssi = call Rf1aPacket.rssi(msg);
    rrLqi = call Rf1aPacket.lqi(msg);
    post reportReplyReceive();
//    printf_TESTBED("AnnounceReply: %u %u \r\n", 
//      call CXPacket.source(msg), 
//      call CXPacketMetadata.getReceivedCount(msg));
    printf_SCHED_SR("reply.rx: %x %d (sn %u)\r\n", call CXPacket.source(msg), 
      call CXRoutingTable.distance(call CXPacket.source(msg), TOS_NODE_ID),
      reply->scheduleNum);

    if ((state == S_BASELINE || state == S_CHECKING 
      || state == S_FINAL_CHECKING)
        && (reply->scheduleNum == curSchedule->scheduleNum)){
      nodesReachable[curSRI]++;
      maxDepth[curSRI] = 
        (maxDepth[curSRI] != 0xff && maxDepth[curSRI] > receivedCount)? maxDepth[curSRI] : receivedCount;
      printf_SCHED_SR("sr %u (%u = %u) nr %u md %u\r\n",
        curSchedule->scheduleNum, curSchedule->scheduleNum, curSRI, nodesReachable[curSRI],
        maxDepth[curSRI]);
    } else {
      printf_SCHED("Unexpected reply.rx: state: %x src %u (sn: %u) cur sched: %u\r\n", 
        state, call CXPacket.source(msg), reply->scheduleNum, 
        curSchedule->scheduleNum);
    }
    return msg;
  }

  //Schedule modification functions
  void initializeSchedule(){
//    call AMPacket.clear(cur_schedule_msg);
//    call AMPacket.clear(next_schedule_msg);
    //configure the uninitialized fields in curSchedule
    curSchedule = (cx_schedule_t*)(call Packet.getPayload(cur_schedule_msg,
      sizeof(cx_schedule_t)));
    curSchedule->scheduleNum = 0;
    curSchedule->scheduleId = 0;
    curScheduleDescriptor = &SCHEDULES[curSchedule->scheduleId];
    //initialize nextSchedule
    resetNextSR(TRUE, TRUE);
    //this timestamp will be fed to the phy scheduler.
    call CXPacket.setTimestamp(next_schedule_msg, 
      call TDMAPhySchedule.getNow());
    //post task to start lower layer and swap cur with next
    useNextSchedule();
    post printSchedule();
    //set up next identical to this one 
    keepNextSR(FALSE);
  }

  task void updateScheduleTask(){
    error_t error;
    printf_SCHED_SR("UST\r\n");
    error = call TDMAPhySchedule.setSchedule(
      call CXPacket.getTimestamp(cur_schedule_msg), 
      call CXPacket.getOriginalFrameNum(cur_schedule_msg),
      frameLens[srIndex(curSchedule->symbolRate)],
      fwCheckLens[srIndex(curSchedule->symbolRate)],
      SCHEDULES[curSchedule->scheduleId].activeFrames,
      SCHEDULES[curSchedule->scheduleId].inactiveFrames,
      curSchedule->symbolRate,
      SCHEDULES[curSchedule->scheduleId].channel,
      TRUE
    );
    if (SUCCESS != error){
      printf("Unable to update schedule: %s\r\n", decodeError(error));
    } else {
      printf_SCHED_SR("UST OK\r\n");
      curSR = curSchedule->symbolRate;
      psState = S_SET;
    }
  }

  void useNextSchedule(){
    message_t* swp = cur_schedule_msg;
    lastSR = curSchedule->symbolRate;
    cur_schedule_msg = next_schedule_msg;
    curSchedule = (cx_schedule_t*) call Packet.getPayload(cur_schedule_msg, sizeof(cx_schedule_t));
    curScheduleDescriptor = &SCHEDULES[curSchedule->scheduleId];
    next_schedule_msg = swp;
    psState = S_SWITCH_PENDING;
    post updateScheduleTask();
  }

  //Tests
  bool disconnected(){
    bool ret;
    ret = nodesReachable[srIndex(curSchedule->symbolRate)] != totalNodes;
    return ret;
  }

  bool higherSRChecked(){
    return (maxDepth[srIndex(curSR)+1] != 0xff);
  }

  bool lowerMoreEfficient(){
    uint8_t lastDepth;
    uint8_t curDepth;
    lastDepth = maxDepth[srIndex(lastSR)];
    curDepth = maxDepth[srIndex(curSR)];
//    printf_SCHED_SR("last %u cur %u: %u *%u < %u * %u\r\n",
//      lastSR, curSR, curSR, lastDepth, lastSR, curDepth);
    //TRUE: lastDepth/lastSR < curDepth/curSR
    return curSR * lastDepth < lastSR * curDepth;
  }
  
  bool maxSRKnown(){
    return srState == S_DISCOVERED;
  }


  //Schedule announcement modification functions
  void resetCounts(){
    uint8_t i;
    for(i = 0 ; i<NUM_SRS; i++){
      maxDepth[i] = 0xff;
      nodesReachable[i] = 0;
    }
  }

  void resetMaxSR(){
    srState = S_UNKNOWN;
    maxSR = 0;
  }

  void resetNextSR(bool resetC, bool resetM){
    setupPacket(next_schedule_msg,
      (curSchedule->scheduleNum+1)%0xff,
      TDMA_INIT_SYMBOLRATE,
      TDMA_INIT_SCHEDULE_ID
    );
    if (resetC){
      resetCounts();
    }
    if (resetM){
      resetMaxSR();
    }
  }

  bool increaseNextSR(){
    uint8_t curSRI ;
    curSRI = srIndex(curSchedule->symbolRate);
    //OK to increase if we will not exceed maximum-established symbol
    //rate.
    if ( curSRI < NUM_SRS - 1 ){
      setupPacket(next_schedule_msg,
        (curSchedule->scheduleNum+1)%0xff,
        symbolRates[curSRI + 1],
        TDMA_INIT_SCHEDULE_ID
      );
      nextSR = ((cx_schedule_t*)
        (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
        )->symbolRate;
      return TRUE;
    }else{
      //already at the maximum symbol rate.
      return FALSE;
    }
  }

  bool decreaseNextSR(){
    uint8_t curSRI ;
    curSRI = srIndex(curSchedule->symbolRate);
    //OK to decrease if we are not already at min 
    if ( curSRI > 0 ){
      setupPacket(next_schedule_msg,
        (curSchedule->scheduleNum+1)%0xff,
        symbolRates[curSRI - 1],
        TDMA_INIT_SCHEDULE_ID
      );
      nextSR = ((cx_schedule_t*)
        (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
        )->symbolRate;
      return TRUE;
    }else{
      //already at the minimum symbol rate.
      return FALSE;
    }
  }

  void finalizeNextSR(){
    setupPacket(next_schedule_msg,
      (curSchedule->scheduleNum+1)%0xff,
      maxSR,
      TDMA_INIT_SCHEDULE_ID
    );
    nextSR = ((cx_schedule_t*)
      (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
      )->symbolRate;
  }

  void keepNextSR(bool increaseSN){
    uint8_t nextSN;
    if (increaseSN){
      nextSN = (curSchedule->scheduleNum+1)%0xff;
    } else {
      nextSN = curSchedule->scheduleNum;
    }
    setupPacket(next_schedule_msg,
      nextSN,
      curSchedule->symbolRate,
      TDMA_INIT_SCHEDULE_ID
    );
    printf_SCHED_SR("KN %p sr %u\r\n", next_schedule_msg,
      ((cx_schedule_t*)(call Packet.getPayload(next_schedule_msg,
      sizeof(cx_schedule_t))))->symbolRate);
  }

  //general packet setup
  void setupPacket(message_t* msg, 
      uint8_t sn, 
      uint8_t symbolRate, 
      uint8_t scheduleId){
    cx_schedule_t* schedule; 
    //not necessary, this is done by the send component
    //call CXPacket.init(msg);
    call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(msg, AM_BROADCAST_ADDR);
    schedule = (cx_schedule_t*)call Packet.getPayload(msg, sizeof(cx_schedule_t));
//    schedule -> frameLen = frameLens[srIndex(symbolRate)];
//    schedule -> fwCheckLen = fwCheckLens[srIndex(symbolRate)];
//    schedule -> activeFrames = activeFrames;
//    schedule -> inactiveFrames = inactiveFrames;
//    schedule -> framesPerSlot = framesPerSlot;
//    schedule -> maxRetransmit = maxRetransmit;
    schedule -> symbolRate = symbolRate;
//    schedule -> channel = channel;
    schedule -> scheduleNum = sn;
    schedule -> scheduleId = scheduleId;
  }

  //utilities
  task void printSchedule(){
    printf_SCHED("sn %u of %u si %u (%p) sri %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u chan %u\r\n", 
      curSchedule->scheduleNum, call
      CXPacket.getOriginalFrameNum(cur_schedule_msg),
      curSchedule->scheduleId,
      curScheduleDescriptor,
      srIndex(curSchedule->symbolRate),
      frameLens[srIndex(curSchedule->symbolRate)],
      fwCheckLens[srIndex(curSchedule->symbolRate)],
      curScheduleDescriptor->activeFrames, 
      curScheduleDescriptor->inactiveFrames, curScheduleDescriptor->framesPerSlot, 
      curScheduleDescriptor->maxRetransmit, curSchedule->symbolRate,
      curScheduleDescriptor->channel);
  }
  
  //TODO: split control
  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }
  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  //unused
  event void ReplySend.sendDone(message_t* msg, error_t error){}
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return msg; 
  }
  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ }

  async event void TDMAPhySchedule.peek(message_t* msg, 
      uint16_t frameNum, uint32_t rxTime){
    //don't need to do anything here, we're the boss.
  }

  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    return curSchedule->scheduleNum;
  }


}
