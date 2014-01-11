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
module MasterSchedulerStaticP {
  provides interface TDMARoutingSchedule;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SlotStarted;

  uses interface AMSend as AnnounceSend;
  //always pegged to announcementSlot
  provides interface ScheduledSend as AnnounceSchedule;
  uses interface Receive as RequestReceive;
  uses interface AMSend as ResponseSend;
  uses interface PacketAcknowledgements;
  //peg to slot being granted
  provides interface ScheduledSend as ResponseSchedule;

  uses interface ExternalScheduler;

  uses interface CXPacket;
  uses interface ReceiveNotify;

  provides interface ScheduledSend as DefaultScheduledSend;

} implementation {
  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  cx_schedule_t* schedule;
  
  //in general:
  // if responsesPending, do a series of ResponseSend's to clear out
  //   the queue of pending responses
  // if requestsReceived, update assignments at end of cycle

  //for designating transmissions which are dependent on position in
  //  cycle
  //TODO: announcement/data might be defined externally.
  uint16_t announcementSlot = 0;
  uint16_t responseSlot = INVALID_SLOT;
  uint16_t dataSlot = 1;

  bool inactiveSlot = FALSE;
  uint16_t totalFrames;

  //pre-compute for faster idle-check
  uint16_t firstIdleFrame;
  uint16_t lastIdleFrame;

  uint16_t curSlot = INVALID_SLOT;
  uint16_t curFrame = INVALID_SLOT;
 
  //S_OFF
  // start / TDMAPhySchedule.set, AnnounceSend.send 
  // -> S_IDLE
  
  //S_IDLE / S_REQUESTS_RECEIVED
  // AnnounceSend.sendDone / -
  // -> S_IDLE

  //S_IDLE/S_REQUESTS_RECEIVED/S_RESPONSES_PENDING
  // RequestReceive.receive / record new assignment
  // -> S_REQUESTS_RECEIVED/S_RESPONSES_PENDING
  
  //S_REQUESTS_RECEIVED
  // cycle start / 
  // -> S_RESPONSE_PENDING
  
  //S_REQUESTS_RECEIVED
  // cycle end / update available slots, post AnnounceSend.send,
  //   call ResponseSend.send (peg to first assigned slot)  
  // -> S_RESPONSES_PENDING

  //S_RESPONSES_PENDING
  // ResponseSend.sendDone + more pending / call ResponseSend.send
  // -> S_RESPONSES_PENDING

  void setSymbolRate(cx_schedule_t* sched, uint8_t symbolRate){ }
  void setChannel(cx_schedule_t* sched, uint8_t channel){}
  void setSlots(cx_schedule_t* sched, uint16_t slots){ }
  void setFramesPerSlot(cx_schedule_t* sched, uint16_t framesPerSlot){ }
  void setMaxRetransmit(cx_schedule_t* sched, uint8_t maxRetransmit){ }
  void setFirstIdleSlot(cx_schedule_t* sched, uint16_t firstIdleSlot){ }
  void setLastIdleSlot(cx_schedule_t* sched, uint16_t lastIdleSlot){ }

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
  
  command error_t SplitControl.start(){
    uint8_t i;
    schedule = call AnnounceSend.getPayload(schedule_msg,
      sizeof(cx_schedule_t));
    schedule->scheduleNum++;
    setSymbolRate(schedule, SCHED_INIT_SYMBOLRATE);
    setChannel(schedule, TEST_CHANNEL);
    setSlots(schedule, SCHED_NUM_SLOTS);
    setFramesPerSlot(schedule, SCHED_FRAMES_PER_SLOT);
    setMaxRetransmit(schedule, SCHED_MAX_RETRANSMIT);
    totalFrames = getFramesPerSlot(schedule) * getSlots(schedule);
    for (i=0; i< SCHED_PADDING_LEN; i++){
      schedule->padding[i] = 0xDC;
    }

    return call SubSplitControl.start();
  }
  
  task void requestExternalSchedule();
  event void SubSplitControl.startDone(error_t error){
    post requestExternalSchedule();
  }

  task void recomputeSchedule();
  task void requestExternalSchedule(){
    error_t err = call TDMAPhySchedule.setSchedule( 
      call ExternalScheduler.getStartTime(call TDMAPhySchedule.getNow()),
      call ExternalScheduler.getStartFrame(),
      getFramesPerSlot(schedule)*getSlots(schedule),
      getSymbolRate(schedule),
      getChannel(schedule), 
      TRUE,
      CX_ENABLE_SKEW_CORRECTION);
////removed: this will get setup next go-around
//    if (SUCCESS == err){
//      post recomputeSchedule();
//    }
    signal SplitControl.startDone(err);
  }

  //by default, start the schedule as soon as the radio is on and
  //begins at slot 0. Wiring
  //to this interface will let you use an RTC, for instance, to set
  //the start point.
  default command uint32_t ExternalScheduler.getStartTime(uint32_t curTime){
    //TODO: unhardcode this: appx. 10 ms in the future
    return curTime + 65000UL;
  }
  default command uint16_t ExternalScheduler.getStartFrame(){
    return totalFrames-1;
  }

  void printSchedule(){
    printf_TMP("SCHED: sn %u sr %u chan %u slots %u fps %u mr %u fis %u lis %u [",
      schedule->scheduleNum,
      getSymbolRate(schedule),
      getChannel(schedule),
      getSlots(schedule),
      getFramesPerSlot(schedule),
      getMaxRetransmit(schedule),
      getFirstIdleSlot(schedule),
      getLastIdleSlot(schedule)
    );
    printf_TMP("]\r\n");
   }

  task void printScheduleTask(){
    printSchedule();
  }

  task void recomputeSchedule(){
    error_t error;
    setFirstIdleSlot(schedule, STATIC_FIRST_IDLE_SLOT);
    setLastIdleSlot(schedule, SCHED_NUM_SLOTS - 1);
    firstIdleFrame = (getFirstIdleSlot(schedule) * getFramesPerSlot(schedule));
    lastIdleFrame = (getLastIdleSlot(schedule) * getFramesPerSlot(schedule));
    error = call AnnounceSend.send(AM_BROADCAST_ADDR, schedule_msg, sizeof(cx_schedule_t));
    if (error != SUCCESS){
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }
  
  uint16_t getSlot(uint16_t frameNum){
    return frameNum / getFramesPerSlot(schedule);
  }

  //owns announce, data, and response frames
  command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    uint16_t sn = getSlot(frameNum); 
    return sn == announcementSlot || sn == dataSlot;
  }

  command uint16_t TDMARoutingSchedule.maxDepth(){
    //TODO: should this be in the schedule announcement?
    return SCHED_MAX_DEPTH;
  }

  command uint16_t AnnounceSchedule.getSlot(){
    return announcementSlot;
  }
  command bool AnnounceSchedule.sendReady(){
    return TRUE;
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (error != SUCCESS){
      printf("AnnounceSend.sendDone: %s\r\n", decodeError(error));
    }
  }


  event message_t* RequestReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    return msg;
  }

  void adjustSlotStart(uint32_t lastAnnounceTime, 
      uint16_t lastAnnounceFrame, uint16_t targetFrame){
    if (lastAnnounceTime != 0 ){
      //TODO: we should be able to pass in 
      uint32_t targetFrameStart = lastAnnounceTime 
        + ((targetFrame - lastAnnounceFrame)*(call TDMAPhySchedule.getFrameLen()));

//      printf("# ASS %lu %u : %lu %u\r\n", 
//        lastAnnounceTime,
//        lastAnnounceFrame,
//        targetFrameStart,
//        targetFrame);

      call TDMAPhySchedule.adjustFrameStart(targetFrameStart,
        targetFrame);
    }
  }
  
  event void FrameStarted.frameStarted(uint16_t frameNum){
    bool cycleStart = (frameNum == totalFrames - 1);
    bool cycleEnd = (frameNum == totalFrames - 2);
    uint16_t frameOfSlot = frameNum % (call TDMARoutingSchedule.framesPerSlot());
    curFrame = frameNum;

    curSlot = getSlot(frameNum); 
    if (frameOfSlot == (call TDMARoutingSchedule.framesPerSlot() - 1)){
      //self-adjust schedule in case we got bumped during last slot
      //post adjustSlotStart();
      adjustSlotStart(call CXPacket.getTimestamp(schedule_msg),
        call CXPacket.getOriginalFrameNum(schedule_msg),
        frameNum);
    }

    if (curSlot == INVALID_SLOT || 
        frameOfSlot == 0 ){
      inactiveSlot = FALSE;
      signal SlotStarted.slotStarted(curSlot);
    }
    if (cycleStart){
      post recomputeSchedule();
    } else if (cycleEnd){
    } else {
      //nothin'
    }
  }
  
  //doesn't matter, not using responseSend
  command uint16_t ResponseSchedule.getSlot(){
    return 1;
  }
  command bool ResponseSchedule.sendReady(){
    return TRUE;
  }

  event void ResponseSend.sendDone(message_t* msg, error_t error){
  }


  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
  
  event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
    return CX_DUTY_CYCLE_ENABLED 
      && (inactiveSlot || (frameNum > firstIdleFrame && frameNum < lastIdleFrame));
  }

  command error_t TDMARoutingSchedule.inactiveSlot(){
    inactiveSlot = TRUE;
    return SUCCESS;
  }

  event uint8_t TDMAPhySchedule.getScheduleNum(){
    return schedule->scheduleNum;
  }

  event void TDMAPhySchedule.resynched(uint16_t frameNum){ }
  
  command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return getFramesPerSlot(schedule);
  }
  command bool TDMARoutingSchedule.isSynched(){
    return TRUE;
  }
  command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return getMaxRetransmit(schedule);
  }
  command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return getFramesPerSlot(schedule) - (frameNum % getFramesPerSlot(schedule));
  }
  
  command uint16_t DefaultScheduledSend.getSlot(){
    return dataSlot;
  }

  command bool DefaultScheduledSend.sendReady(){
    return call TDMARoutingSchedule.isSynched();
  }

  command uint16_t TDMARoutingSchedule.getNumSlots(){
    return getSlots(schedule);
  }

  command uint16_t TDMARoutingSchedule.currentFrame(){
    return curFrame;
  }

  command uint16_t SlotStarted.currentSlot(){
    return curSlot;
  }

  event void ReceiveNotify.received(am_addr_t from){
  }
}

