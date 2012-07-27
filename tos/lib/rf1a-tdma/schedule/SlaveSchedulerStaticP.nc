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
  bool isSynched = FALSE;
  bool claimedLast = FALSE;
  bool hasStarted = FALSE;

  uint16_t curSlot = INVALID_SLOT;
  uint16_t curFrame = INVALID_SLOT;

  uint8_t cyclesSinceSchedule = 0;
  uint16_t framesSinceSynch = 0;

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
    isSynched = FALSE;
    mySlot = INVALID_SLOT;
    call TDMAPhySchedule.setSchedule(call TDMAPhySchedule.getNow(),
      0, 
      1, 
      SCHED_INIT_SYMBOLRATE,
      TEST_CHANNEL,
      isSynched
      );
  }

  task void updateSchedule(){
    uint8_t sri = srIndex(schedule->symbolRate);
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
      isSynched
    );
    firstIdleFrame = (schedule->firstIdleSlot  * schedule->framesPerSlot);
    lastIdleFrame = (schedule->lastIdleSlot * schedule->framesPerSlot);
    if (state == S_LISTEN){
      state = S_READY;
      post startDoneTask();
    }
    mySlot = TOS_NODE_ID;
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
    return (state != S_LISTEN) && (schedule != NULL) 
      && (frameNum > firstIdleFrame && frameNum < lastIdleFrame);
  }

  event uint8_t TDMAPhySchedule.getScheduleNum(){
    return scheduleNum;
  }
  
  event void TDMAPhySchedule.resynched(uint16_t resynchFrame){
    isSynched = TRUE;
    framesSinceSynch = 0;
  }

  command bool TDMARoutingSchedule.isSynched(){
    return isSynched;
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

