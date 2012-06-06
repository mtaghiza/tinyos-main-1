
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

} implementation {
  //which nodes are assigned to which slots
  assignment_t assignments[SCHED_NUM_SLOTS];

  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;
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

  //the point at which we send announcements
  uint16_t announcementSlot;
 
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
    printf_TMP("Schedule msg %p pl %p\r\n", schedule_msg, schedule);
    schedule->scheduleNum++;
    schedule->symbolRate = SCHED_INIT_SYMBOLRATE;
    schedule->channel = TEST_CHANNEL;
    schedule->slots = SCHED_NUM_SLOTS;
    schedule->framesPerSlot = SCHED_FRAMES_PER_SLOT;
    schedule->maxRetransmit = SCHED_MAX_RETRANSMIT;

    for (i=0; i < SCHED_NUM_SLOTS; i++){
      assignments[i].owner = UNCLAIMED;   
    }
    //TODO: the slot numbers here may be informed from outside
    //for announcements
    assignments[0].owner = TOS_NODE_ID;
    assignments[0].notified = TRUE;
    //for other data
    assignments[1].owner = TOS_NODE_ID;
    assignments[1].notified = TRUE;
    return call SubSplitControl.start();
  }
  
  task void requestExternalSchedule();
  event void SubSplitControl.startDone(error_t error){
    printf("%s: \r\n", __FUNCTION__);
    post requestExternalSchedule();
  }

  task void recomputeSchedule();
  task void requestExternalSchedule(){
    printf("%s: \r\n", __FUNCTION__);
    printf_TMP("schedule pl %p\r\n", schedule);
    call TDMAPhySchedule.setSchedule( 
      call ExternalScheduler.getStartTime(call TDMAPhySchedule.getNow()),
      call ExternalScheduler.getStartFrame(),
      schedule->framesPerSlot*schedule->slots,
      schedule->symbolRate,
      schedule->channel, 
      TRUE);
//    post recomputeSchedule();
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

  task void recomputeSchedule(){
    uint8_t i;
    uint8_t j;
    //TODO: go through assignments and set up availableSlots in
    //schedule
    for (i = 0 ; i < SCHED_NUM_SLOTS; i++){
      if (assignments[i].owner == UNCLAIMED && j < MAX_ANNOUNCED_SLOTS){
        //TODO: fill in availableSlots[j]
        j++;
      }
    }
    //TODO: eviction
    //TODO: update idle periods
    call AnnounceSend.send(AM_BROADCAST_ADDR, schedule_msg, sizeof(cx_schedule_t));
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
    requestsReceived = TRUE;
    //TODO: read slot, sender out of it.
    //TODO: update assignments if this slot is still available.
    return msg;
  }
  
  async event void FrameStarted.frameStarted(uint16_t frameNum){
    //TODO: fill these bools in
    bool cycleStart = FALSE;
    bool cycleEnd = FALSE;
    if (cycleStart){
      post recomputeSchedule();
    } else if (cycleEnd){
      responsesPending = requestsReceived;
    } else {
      //nothin'
      if (frameNum %10 == 0){
        printf("FS %u \r\n", frameNum);
      }
    }
  }

  task void checkResponses(){
    if (responsesPending){
      //TODO: find first assigned un-notified slot (return if none)
      //TODO: set up response_msg accordingly
      //TODO: call ResponseSend.send with it
    }
  }

////TODO:uncomment when this interface exists
//  event uint16_t ResponseSchedule.getSlot(){
//    //TODO: return the slot designated by response
//  }

  event void ResponseSend.sendDone(message_t* msg, error_t error){
    //TODO: update assignments
    post checkResponses();
  }


  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
    //TODO: return true if frameNum is between firstIdle and lastIdle,
    //or is in an unannounced+unassigned slot.
    return TRUE;
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, uint16_t frameNum){}
  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){ return 0;}
  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    //TODO: return current schedule num
    return 0;
  }
  async event void TDMAPhySchedule.peek(message_t* msg, uint16_t frameNum, 
    uint32_t timestamp){}
  
  //TODO: fill 'em in
  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return 0;
  }
  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return FALSE;
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return 0;
  }
  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    return FALSE;
  }
  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return 0;
  }
  
}
