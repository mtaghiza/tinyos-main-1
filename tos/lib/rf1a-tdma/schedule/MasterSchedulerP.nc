
 #include "schedule.h"
module MasterSchedulerP {
  provides interface TDMARoutingSchedule;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface AMSend as AnnounceSend;
  ////always pegged to announcementSlot
  //provides interface ScheduledSend as AnnounceSchedule;
  uses interface Receive as RequestReceive;
  uses interface AMSend as ResponseSend;
  ////peg to slot being granted
  //provides interface ScheduledSend as ResponseSchedule;

  uses interface ExternalScheduler;

  uses interface CXPacket;

} implementation {
  //which nodes are assigned to which slots
  assignment_t assignments[SCHED_NUM_SLOTS];

  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  message_t response_msg_internal;
  message_t* response_msg = &response_msg_internal;

  cx_schedule_t* schedule;
  
  //state variables
  //These can actually be checked implicitly from the assignments
  //table, but that would be much slower. 
  //requestsReceived: set when request received, cleared at start of cycle.
  norace bool requestsReceived;

  //responsesPending: set to requestsReceived at end of cycle, cleared
  //  when last response sent
  norace bool responsesPending;

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
    call TDMAPhySchedule.setSchedule( 
      call ExternalScheduler.getStartTime(call TDMAPhySchedule.getNow()),
      call ExternalScheduler.getStartFrame(),
      schedule->framesPerSlot*schedule->slots,
      schedule->symbolRate,
      schedule->channel, 
      TRUE);
    post recomputeSchedule();
  }

  //by default, start the schedule as soon as the radio is on and
  //begins at slot 0. Wiring
  //to this interface will let you use an RTC, for instance, to set
  //the start point.
  default command uint32_t ExternalScheduler.getStartTime(uint32_t curTime){
    return curTime;
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
      if (assignments[i].owner == UNCLAIMED &&
           j < MAX_ANNOUNCED_SLOTS){
        schedule->availableSlots[j] = i;
        j++;
        lastAnnounced = i;
      }
    }

    //TODO: eviction of unused slots

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
  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    uint16_t sn = getSlot(frameNum); 
    return sn == announcementSlot || sn == dataSlot || sn == responseSlot;
  }

////TODO:uncomment when this interface exists
//  event uint16_t AnnounceSchedule.getSlot(){
//    return announcementSlot;
//  }

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
    }
    return msg;
  }
  
  async event void FrameStarted.frameStarted(uint16_t frameNum){
    bool cycleStart = (frameNum == totalFrames - 1);
    bool cycleEnd = (frameNum == totalFrames - 2);
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
      uint8_t i;
      //find first assigned un-notified slot 
      for (i = 0; i < SCHED_NUM_SLOTS; i++){
        if (assignments[i].owner != UNCLAIMED 
            && !assignments[i].notified){
          error_t error;
          //inform node it's been assigned
          cx_response_t* response 
            = call ResponseSend.getPayload(response_msg, sizeof(cx_response_t));
          response->slotNumber = i;
          response->owner = assignments[i].owner;
           
          error = call ResponseSend.send(response->owner,
            response_msg, 
            sizeof(cx_response_t));
          if (error != SUCCESS){
            printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
          }
          responseSlot = response->slotNumber;
          break;
        }
      }
    }else{
      responseSlot = INVALID_SLOT;
    }
  }

////TODO:uncomment when this interface exists
//  event uint16_t ResponseSchedule.getSlot(){
//    //TODO: return the slot designated by response
//  }

  event void ResponseSend.sendDone(message_t* msg, error_t error){
    if ( error == SUCCESS){
      cx_response_t* response = call ResponseSend.getPayload(msg,
        sizeof(cx_response_t));
      assignments[response->slotNumber].notified = TRUE;
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
  
  async event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
    return (frameNum > firstIdleFrame && frameNum < lastIdleFrame);
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, uint16_t frameNum){}
  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){ return 0;}
  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    return schedule->scheduleNum;
  }

  async event void TDMAPhySchedule.peek(message_t* msg, uint16_t frameNum, 
    uint32_t timestamp){}
  
  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return schedule->framesPerSlot;
  }
  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return TRUE;
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return schedule->maxRetransmit;
  }
  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return schedule->framesPerSlot - (frameNum % schedule->framesPerSlot);
  }
  
}
