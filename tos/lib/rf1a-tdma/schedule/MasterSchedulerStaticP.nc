
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

  command error_t SplitControl.start(){
    schedule = call AnnounceSend.getPayload(schedule_msg,
      sizeof(cx_schedule_t));
    schedule->scheduleNum++;
    schedule->symbolRate = SCHED_INIT_SYMBOLRATE;
    schedule->channel = TEST_CHANNEL;
    schedule->slots = SCHED_NUM_SLOTS;
    schedule->framesPerSlot = SCHED_FRAMES_PER_SLOT;
    schedule->maxRetransmit = SCHED_MAX_RETRANSMIT;
    totalFrames = schedule->framesPerSlot * schedule->slots;

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
    error_t error;
    for (i = 0; i< MAX_ANNOUNCED_SLOTS; i++){
      schedule->availableSlots[i] = INVALID_SLOT;
    }
    schedule->firstIdleSlot = STATIC_FIRST_IDLE_SLOT;
    schedule->lastIdleSlot = SCHED_NUM_SLOTS - 1;
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
  
  event void FrameStarted.frameStarted(uint16_t frameNum){
    bool cycleStart = (frameNum == totalFrames - 1);
    bool cycleEnd = (frameNum == totalFrames - 2);
    curFrame = frameNum;
    if (curSlot == INVALID_SLOT || 
        0 == (frameNum % (call TDMARoutingSchedule.framesPerSlot())) ){
      uint32_t last_announce = call CXPacket.getTimestamp(schedule_msg);
      curSlot = getSlot(frameNum); 
      inactiveSlot = FALSE;
      //self-adjust schedule in case we got bumped during last slot
//      if (last_announce !=0){
//        call TDMAPhySchedule.setSchedule( 
//          last_announce + (frameNum*(call TDMAPhySchedule.getFrameLen())),
//          frameNum,
//          schedule->framesPerSlot*schedule->slots,
//          schedule->symbolRate,
//          schedule->channel, 
//          TRUE,
//          CX_ENABLE_SKEW_CORRECTION);
//      }


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
  }
}

