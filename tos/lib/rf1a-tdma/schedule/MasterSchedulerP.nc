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
module MasterSchedulerP {
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
  //which nodes are assigned to which slots
  assignment_t assignments[SCHED_NUM_SLOTS];

  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  message_t response_msg_internal;
  message_t* response_msg = &response_msg_internal;

  cx_schedule_t* schedule;
  bool inactiveSlot = FALSE;
  
  //state variables
  //These can actually be checked implicitly from the assignments
  //table, but that would be much slower. 
  //requestsReceived: set when request received, cleared at start of cycle.
  norace bool requestsReceived;

  //responsesPending: set to requestsReceived at end of cycle, cleared
  //  when last response sent
  norace bool responsesPending;
  bool responseSending = FALSE;

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

  command error_t SplitControl.start(){
    uint8_t i;
    schedule = call AnnounceSend.getPayload(schedule_msg,
      sizeof(cx_schedule_t));
    schedule->scheduleNum++;
    schedule->symbolRate = SCHED_INIT_SYMBOLRATE;
    schedule->channel = TEST_CHANNEL;
    schedule->slots = SCHED_NUM_SLOTS;
    schedule->framesPerSlot = SCHED_FRAMES_PER_SLOT;
    schedule->maxRetransmit = SCHED_MAX_RETRANSMIT;
    totalFrames = schedule->framesPerSlot * schedule->slots;
    for (i=0; i < SCHED_NUM_SLOTS; i++){
      assignments[i].owner = UNCLAIMED;   
    }
    assignments[announcementSlot].owner = TOS_NODE_ID;
    assignments[announcementSlot].notified = TRUE;

    assignments[dataSlot].owner = TOS_NODE_ID;
    assignments[dataSlot].notified = TRUE;
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
      schedule->framesPerSlot*schedule->slots,
      schedule->symbolRate,
      schedule->channel, 
      TRUE);
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
    return 0;
  }

  void printSchedule(){
    uint8_t i;
    printf_TMP("SCHED: sn %u sr %u chan %u slots %u fps %u mr %u fis %u lis %u [",
      schedule->scheduleNum,
      schedule->symbolRate,
      schedule->channel,
      schedule->slots,
      schedule->framesPerSlot,
      schedule->maxRetransmit,
      schedule->firstIdleSlot,
      schedule->lastIdleSlot
    );
    for (i = 0; i < MAX_ANNOUNCED_SLOTS; i++){
      printf_TMP(" %u, ", schedule->availableSlots[i]);
    }
    printf_TMP("]\r\n");
   }

  task void printScheduleTask(){
    printSchedule();
  }

  task void recomputeSchedule(){
    uint16_t i;
    uint8_t j;
    error_t error;
    uint16_t lastAnnounced = 0;
    for (i = 0; i< MAX_ANNOUNCED_SLOTS; i++){
      schedule->availableSlots[i] = INVALID_SLOT;
    }
    for (i = 0 ; i < SCHED_NUM_SLOTS; i++){
      assignments[i].absentCycles++;
      //evict missing nodes
      if (assignments[i].owner != TOS_NODE_ID 
          && assignments[i].owner != UNCLAIMED 
          && assignments[i].absentCycles > CX_KEEPALIVE_CYCLES){
        printf_SCHED_RXTX("Evict %u @%u\r\n", 
          assignments[i].owner, i);
        assignments[i].owner = UNCLAIMED;
        assignments[i].notified = FALSE;
      }
      if (assignments[i].owner == UNCLAIMED &&
           j < MAX_ANNOUNCED_SLOTS){
        schedule->availableSlots[j] = i;
        j++;
        lastAnnounced = i;
      }
    }
    

    //update idle periods of schedule. Currently assumes that the end
    //of the cycle is the last to be filled in.
    schedule->lastIdleSlot = SCHED_NUM_SLOTS;
    i = SCHED_NUM_SLOTS-1;
    while (i > 0 && assignments[i].owner == UNCLAIMED){
      i --;
    }
    //announced+unassigned slots should not be idle
    schedule->firstIdleSlot = 1+(lastAnnounced > i? lastAnnounced:i);
    firstIdleFrame = (schedule->firstIdleSlot  * schedule->framesPerSlot);
    lastIdleFrame = (schedule->lastIdleSlot * schedule->framesPerSlot);
//    printSchedule();
//    post printScheduleTask();
    error = call AnnounceSend.send(AM_BROADCAST_ADDR, schedule_msg, sizeof(cx_schedule_t));
    if (error != SUCCESS){
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }
  
  uint16_t getSlot(uint16_t frameNum){
    return frameNum / schedule->framesPerSlot;
  }

  //owns announce, data, and response frames
  command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    uint16_t sn = getSlot(frameNum); 
    return sn == announcementSlot || sn == dataSlot || sn == responseSlot;
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

  task void checkResponses();

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (error == SUCCESS){
      post checkResponses();
    }else{
      printf("AnnounceSend.sendDone: %s\r\n", decodeError(error));
    }
  }


  event message_t* RequestReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    cx_request_t* request = (cx_request_t*)pl;
    requestsReceived = TRUE;
    if ( assignments[request->slotNumber].owner == UNCLAIMED){
      assignments[request->slotNumber].owner 
        = call CXPacket.source(msg);
      assignments[request->slotNumber].absentCycles = 0;
    }
    return msg;
  }
  
  event void FrameStarted.frameStarted(uint16_t frameNum){
    bool cycleStart = (frameNum == totalFrames - 1);
    bool cycleEnd = (frameNum == totalFrames - 2);
    curFrame = frameNum;
    if (curSlot == INVALID_SLOT || 
        0 == (frameNum % (call TDMARoutingSchedule.framesPerSlot())) ){
      curSlot = getSlot(frameNum); 
      inactiveSlot = FALSE;
      signal SlotStarted.slotStarted(curSlot);
    }
    if (cycleStart){
      post recomputeSchedule();
    } else if (cycleEnd){
      responsesPending = requestsReceived;
    } else {
      //nothin'
    }
  }

  task void checkResponses(){
    if (responsesPending){
      if (!responseSending){
        uint8_t i, j,k;
        uint8_t startSlot = (responseSlot == INVALID_SLOT)? 0:
          responseSlot+1;
        //find first assigned un-notified slot 
        for (j = 0; j < SCHED_NUM_SLOTS; j++){
          i = (startSlot + j) % SCHED_NUM_SLOTS;
          if (assignments[i].owner != UNCLAIMED 
              && !assignments[i].notified){
            error_t error;

            //inform node it's been assigned
            cx_response_t* response 
              = call ResponseSend.getPayload(response_msg, sizeof(cx_response_t));
            response->slotNumber = i;
            response->owner = assignments[i].owner;

            //free any previously-claimed slots for this node
            for (k =0; k < SCHED_NUM_SLOTS; k++){
              if (k != i && 
                  assignments[k].owner == assignments[i].owner){
                printf_SCHED_RXTX("Free %u (%u)\r\n", 
                  k, assignments[k].owner);
                assignments[k].owner = UNCLAIMED;
                assignments[k].notified = FALSE;
              }
            }
            call PacketAcknowledgements.requestAck(response_msg); 
            error = call ResponseSend.send(response->owner,
              response_msg, 
              sizeof(cx_response_t));
            printf_SCHED_RXTX("Assign %u to %u (%u/%u)\r\n", response->owner,
              response->slotNumber, 
              sizeof(cx_schedule_t), 
              call ResponseSend.maxPayloadLength());
            if (error != SUCCESS){
              printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
            }else{
              responseSending = TRUE;
              responseSlot = response->slotNumber;
            }
            break;
          }
        }
      }
    }else{
      responseSlot = INVALID_SLOT;
    }
  }

  command uint16_t ResponseSchedule.getSlot(){
    return ((cx_response_t*)call ResponseSend.getPayload(response_msg,
      sizeof(cx_response_t)))->slotNumber;
  }
  command bool ResponseSchedule.sendReady(){
    return TRUE;
  }

  event void ResponseSend.sendDone(message_t* msg, error_t error){
    if ( error == SUCCESS || error == ENOACK){
      cx_response_t* response = call ResponseSend.getPayload(msg,
        sizeof(cx_response_t));
      responseSending = FALSE;
      if (error == SUCCESS){
        printf_SCHED_RXTX("Assigned %u to %u\r\n", response->owner,
          response->slotNumber);
        assignments[response->slotNumber].notified = TRUE;
      } else {
        printf_SCHED_RXTX("No ack from %u @ %u\r\n", response->owner,
          response->slotNumber);
        assignments[response->slotNumber].owner = UNCLAIMED;
      }
      post checkResponses();
    } else{ 
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }


  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
  
  event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
    return inactiveSlot || (frameNum > firstIdleFrame && frameNum < lastIdleFrame);
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
    return schedule->framesPerSlot;
  }
  command bool TDMARoutingSchedule.isSynched(){
    return TRUE;
  }
  command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return schedule->maxRetransmit;
  }
  command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return schedule->framesPerSlot - (frameNum % schedule->framesPerSlot);
  }
  
  command uint16_t DefaultScheduledSend.getSlot(){
    return dataSlot;
  }

  command bool DefaultScheduledSend.sendReady(){
    return call TDMARoutingSchedule.isSynched();
  }

  command uint16_t TDMARoutingSchedule.getNumSlots(){
    return schedule->slots;
  }

  command uint16_t TDMARoutingSchedule.currentFrame(){
    return curFrame;
  }

  command uint16_t SlotStarted.currentSlot(){
    return curSlot;
  }

  event void ReceiveNotify.received(am_addr_t from){
    uint8_t i;
    for (i = 0; i < SCHED_NUM_SLOTS; i++){
      if (assignments[i].owner == from){
        assignments[i].absentCycles = 0;
      }
    }
  }
}
