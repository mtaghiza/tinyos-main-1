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
  bool isSynched = FALSE;
  bool claimedLast = FALSE;
  bool hasStarted = FALSE;
  bool inactiveSlot = FALSE;

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

  #define SKEW_HISTORY 2
  uint32_t delta_root [SKEW_HISTORY];
  uint32_t delta_leaf [SKEW_HISTORY];
  uint32_t last_root;
  uint32_t last_leaf;
  uint8_t skew_index = 0;
  int32_t lag_per_cycle;
  int32_t lag_per_slot;

  task void updateSchedule(){
    uint32_t cur_root;
    uint32_t cur_leaf;
    uint8_t sri = srIndex(schedule->symbolRate);
    isSynched = TRUE;
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
    //TODO: handle wrap (maybe? should be cool.)
    if (last_root != 0){
      int32_t lagTot = 0;
      uint8_t i;
      delta_root[skew_index] = cur_root - last_root;
      delta_leaf[skew_index] = cur_leaf - last_leaf;
      for(i = 0; i< SKEW_HISTORY && delta_root[i] != 0 ; i++){
        lagTot += delta_root[i] - delta_leaf[i];
      }
      lag_per_cycle = lagTot/(i-1);
      lag_per_slot = lag_per_cycle / schedule->slots;
      skew_index = (skew_index+1)%SKEW_HISTORY;
    }
    last_root = cur_root;
    last_leaf = cur_leaf;

    call TDMAPhySchedule.setSchedule(
      cur_leaf,
      call CXPacket.getOriginalFrameNum(schedule_msg),
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
    //make sure that root -> self distance retained.
    call CXRoutingTable.setPinned(call AMPacket.source(msg),
      TOS_NODE_ID, TRUE, TRUE);
    schedule = (cx_schedule_t*)pl;
    post updateSchedule();
    cyclesSinceSchedule = 0;
    if (! isSynched){
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
    if (isSynched   
        && ! newSlot 
        && framesThisSlot > call TDMARoutingSchedule.maxDepth()
        && framesSinceSynch > framesThisSlot){
      call TDMARoutingSchedule.inactiveSlot();
    }
    
    //increment the number of cycles since we last got a schedule
    //  announcement at the start of each cycle.
    if (frameNum == 0){
      cyclesSinceSchedule ++;
      if (cyclesSinceSchedule > CX_RESYNCH_CYCLES && state != S_LISTEN){
        printf_SCHED_RXTX("SYNCH_LOSS\r\n");
        post startListen();
      }
    }


    if (newSlot){
      curSlot = getSlot(frameNum);
      inactiveSlot = FALSE;
    }

    //TODO: this assumes that the schedule is always in slot 0
    //If we haven't gotten schedule yet this cycle, stay unsynched.
    if ((curSlot > 0) 
        && (isSynched && (framesSinceSynch > frameNum))){
      isSynched = FALSE;
    }
    if (newSlot){
//      //TODO: re-synch to estimated root schedule 
//      //issue a setSchedule that uses
//      //  (originalFrameStartEstimate - (slotNum*lag_per_slot),
//      //   originalFrameNum + (slotNum* framesPerSlot))
//      //e.g. if we typically lag, then we need to bump up our start
//      //     time

      call TDMAPhySchedule.setSchedule(
        last_leaf + (frameNum*(call TDMAPhySchedule.getFrameLen())) - (curSlot*lag_per_slot),
        frameNum, 
        schedule->framesPerSlot*schedule->slots,
        schedule->symbolRate,
        schedule->channel,
        isSynched
      );

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
    if ( !isSynched){
      printf_SCHED_RXTX("FAST_RESYNCH\r\n");
      printf_TMP("#Fast resynch@ %u\r\n", resynchFrame);
      isSynched = TRUE;
    }
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

