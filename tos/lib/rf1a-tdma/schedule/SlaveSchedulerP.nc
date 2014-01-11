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
module SlaveSchedulerP {
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

  provides interface SlotStarted;

  provides interface ScheduledSend as RequestScheduledSend;
  provides interface ScheduledSend as DefaultScheduledSend;

  uses interface AMPacket;
  uses interface CXRoutingTable;

} implementation {
  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  message_t request_msg_internal;
  message_t* request_msg = &request_msg_internal;
  
  cx_schedule_t* schedule = NULL;
  uint8_t scheduleNum = INVALID_SCHEDULE_NUM;

  uint16_t firstIdleFrame = 0;
  uint16_t lastIdleFrame = 0;
  uint16_t mySlot = INVALID_SLOT;
  bool isSynched = FALSE;
  bool claimedLast = FALSE;
  bool hasStarted = FALSE;

  uint16_t curSlot = INVALID_SLOT;
  uint16_t curFrame = INVALID_SLOT;

  uint8_t cyclesSinceSchedule = 0;
  uint16_t framesSinceSynch = 0;
  bool inactiveSlot = FALSE;

  enum {
    S_OFF = 0x00,
    S_LISTEN = 0x01,
    S_REQUESTING = 0x02,
    S_CONFIRM_WAIT = 0x03,
    S_READY = 0x05,
  }; 

  uint8_t state = S_OFF;

  uint16_t getSlot(uint16_t frameNum);

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  task void startListen(){
    printf_SCHED_RXTX("start listen\r\n");
    state = S_LISTEN;
    isSynched = FALSE;
    mySlot = INVALID_SLOT;
    call TDMAPhySchedule.setSchedule(call TDMAPhySchedule.getNow(),
      0, 
      1, 
      SCHED_INIT_SYMBOLRATE,
      SCHED_INIT_CHANNEL,
      isSynched,
      FALSE);
  }

  task void claimSlotTask();

  task void updateSchedule(){
    uint8_t sri = srIndex(schedule->symbolRate);
    uint8_t i;
    isSynched = TRUE;
    scheduleNum = schedule->scheduleNum;
    //TODO: clock skew correction
    //OFN 0 and receivedCount 1: should be received at
    //frame 0, not frame 1. 
    call TDMAPhySchedule.setSchedule(
      call CXPacketMetadata.getPhyTimestamp(schedule_msg) -
      sfdDelays[sri] - fsDelays[sri],
      call CXPacket.getOriginalFrameNum(schedule_msg) + call CXPacketMetadata.getReceivedCount(schedule_msg) -1,
      schedule->framesPerSlot*schedule->slots,
      schedule->symbolRate,
      schedule->channel,
      isSynched,
      FALSE
    );
    firstIdleFrame = (schedule->firstIdleSlot  * schedule->framesPerSlot);
    lastIdleFrame = (schedule->lastIdleSlot * schedule->framesPerSlot);

    //this indicates that we sent a request, but got no response.
    if (state == S_CONFIRM_WAIT){
      mySlot = INVALID_SLOT;
      state = S_LISTEN;
    }

    //check for whether YOUR slot is in the list (indicating it
    //was freed by the master (either because the master reset or
    //because your keep-alives got lost)). If it is, pretend that
    //we're searching for a slot again (reset state/mySlot)
    if (mySlot != INVALID_SLOT){
      for (i =0 ; i< MAX_ANNOUNCED_SLOTS; i++){
        if (schedule->availableSlots[i] == mySlot){
          mySlot = INVALID_SLOT;
          state = S_LISTEN;
          break;
        }
      }
    }

    if (mySlot == INVALID_SLOT && state == S_LISTEN){
      state = S_REQUESTING;
      post claimSlotTask();
    }else if (state == S_REQUESTING){
      state = S_CONFIRM_WAIT;
    }
  }

  task void claimSlotTask(){
    uint8_t numValid;
    uint8_t i;
    error_t error;
    cx_request_t* request = call RequestSend.getPayload(request_msg,
      sizeof(cx_request_t));
//    printf_TMP("%s: slots ", __FUNCTION__);
    //pick a valid slot
    for(i = 0; i < MAX_ANNOUNCED_SLOTS; i++){
      if (schedule->availableSlots[i] != INVALID_SLOT){
//        printf_TMP("%u: %u ", i, schedule->availableSlots[i]); 
        numValid++;
      }
    }

//    printf_TMP("\r\n");
    mySlot = schedule->availableSlots[(call Random.rand16() % numValid)];

    //set up packet
    request->slotNumber = mySlot;
    printf_SCHED_RXTX("Claim %u\r\n", mySlot);
    //call RequestSend.send
    call PacketAcknowledgements.requestAck(request_msg);
    error = call RequestSend.send(call CXPacket.source(schedule_msg), 
      request_msg, 
      sizeof(cx_request_t));
    if (error != SUCCESS){
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }

  event message_t* AnnounceReceive.receive(message_t* msg, void* pl, uint8_t len){
    message_t* ret = schedule_msg;
    schedule_msg = msg;
    schedule = (cx_schedule_t*)pl;
    post updateSchedule();
    cyclesSinceSchedule = 0;
    return ret;
  }

  event void SubSplitControl.startDone(error_t error){ 
    post startListen();
  }

  event void SubSplitControl.stopDone(error_t error){ 
    hasStarted = FALSE;
    signal SplitControl.stopDone(error);
  }

  event void FrameStarted.frameStarted(uint16_t frameNum){
    curFrame = frameNum;
    framesSinceSynch++;
    
    //increment the number of cycles since we last got a schedule
    //  announcement at the start of each cycle.
    if (frameNum == 0){
      cyclesSinceSchedule ++;
      if (cyclesSinceSchedule > CX_RESYNCH_CYCLES && state != S_LISTEN){
        post startListen();
      }
    }

    //no synch since the cycle started: so, we shouldn't be initiating
    //  any communications.
    if (isSynched && (framesSinceSynch > frameNum)){
//      printf_TMP("@%u fss %u > fn\r\n", frameNum, framesSinceSynch);
      isSynched = FALSE;
    }

    if (0 == (frameNum % call TDMARoutingSchedule.framesPerSlot())){
      curSlot = getSlot(frameNum);
      inactiveSlot = FALSE;
      signal SlotStarted.slotStarted(curSlot);
    }
  }

  event void RequestSend.sendDone(message_t* msg, error_t error){
    if (error == SUCCESS){
      //now we're waiting for response
      state = S_REQUESTING;
    } else if (error == ENOACK){
      //try again next round.
      mySlot = INVALID_SLOT;
      state = S_LISTEN;
    } else {
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }

  task void startDoneTask(){
    if (!hasStarted){
      hasStarted = TRUE;
      signal SplitControl.startDone(SUCCESS);
    }
  }

  event message_t* ResponseReceive.receive(message_t* msg, void* pl, uint8_t len){
    cx_response_t* response = (cx_response_t*)pl;
    if (response->slotNumber == mySlot){
      if (response->owner == TOS_NODE_ID){
        state = S_READY;
        //confirmed, hooray.
        printf_SCHED_RXTX("Confirmed @%u\r\n", mySlot);
        post startDoneTask();
      }else{
        mySlot = INVALID_SLOT;
        state = S_LISTEN;
        //contradicts us: somebody else claimed it.
        printf_SCHED_RXTX("Contradicted @%u, try again\r\n", mySlot);
        mySlot = INVALID_SLOT;
      }
    }
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
    return inactiveSlot || ((state != S_LISTEN) && (schedule != NULL) 
      && (frameNum > firstIdleFrame && frameNum < lastIdleFrame));
  }

  command error_t TDMARoutingSchedule.inactiveSlot(){
    inactiveSlot = TRUE;
    return SUCCESS;
  }

  event uint8_t TDMAPhySchedule.getScheduleNum(){
    return scheduleNum;
  }
  
  event void TDMAPhySchedule.resynched(uint16_t resynchFrame){
    isSynched = TRUE;
    framesSinceSynch = 0;
  }

  command bool TDMARoutingSchedule.isSynched(){
    // we pretend that we're synched if we're requesting a slot. yugh
    if (state == S_REQUESTING 
        && call SlotStarted.currentSlot() == mySlot){
      return TRUE;
    } else{
      return isSynched;
    }
  }
  
  command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return schedule->framesPerSlot;
  }

  //No retransmissions allowed if we're not in synch.
  command uint8_t TDMARoutingSchedule.maxRetransmit(){
    if (call TDMARoutingSchedule.isSynched()){
      return schedule->maxRetransmit;
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
    return schedule->framesPerSlot - (frameNum % schedule->framesPerSlot);
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
    return (state == S_READY) && isSynched;
  }

  command uint16_t TDMARoutingSchedule.getNumSlots(){
    return schedule->slots;
  }

  command uint16_t SlotStarted.currentSlot(){ 
    return curSlot;
  }
   
}
