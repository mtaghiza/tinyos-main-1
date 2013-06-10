module CXSlaveP {

  provides interface Get<cx_schedule_t*>;
  uses interface CXActivityScheduler;
  
  provides interface SplitControl;

  provides interface RoleSchedule;
  uses interface Timer<T32Khz> as CycleTimer;
  uses interface Timer<T32Khz> as EndCycleTimer;
} implementation {

  cx_schedule_t searchSchedule = {
    //tone + 1 flood
    .slotLength = 2 + SEARCH_MAXDEPTH, 
    //only check for 1 slot in the cycle
    .activeSlots = 1,
    //set for desired search DC
    .numSlots = SEARCH_NUMSLOTS
  };

  cx_schedule_t* sched = &searchSchedule;

  message_t  schedMsg_internal;
  message_t* schedMsg = &schedMsg_internal;


  command error_t SplitControl.start(){
    search();
  }
  
  void search(){
    call ActivityScheduler.stop();
    sched = searchSchedule;
    call StartCycleTimer.startPeriodicAt(
      call StartCycleTimer.getNow() - sched->numSlots * sched->slotLength,
      sched->numSlots * sched->slotLength);
  }

  event void StartCycleTimer.fired(){
    call CXActivityScheduler.setSlotStart(0,
      call CycleTimer.gett0(), call CycleTimer.getdt());
    call EndCycleTimer.startOneShotAt(
      call CycleTimer.gett0(), 
      call CycleTimer.getdt() + sched->activeSlots*sched->slotLength);
  }

  event error_t CXActivityScheduler.slotStarted(uint16_t slotNumber,
      cx_slot_rules_t* rules){
    if (sched == &searchSchedule){
      //searching: long tone-search timeout, check on network beacon
      //channel.
      rules->channel = CX_BEACON_CHANNEL;
      rules->toneTimeout = CX_SEARCH_TONE_TIMEOUT;
      rules->active = TRUE;
      return SUCCESS;
    }else {
      if (tier1Slot(slotNumber)){
        rules->channel = CX_TIER_1_CHANNEL;
        rules->toneTimeout = CX_SYNCHED_TONE_TIMEOUT;
        rules->active = TRUE;
        //waitingForAssignment: we sent a request. needsAssignment: we
        //haven't been assigned yet. So, we need to request again.
        if (waitingForAssignment && needsAssignment){
          waitingForAssignment = FALSE;
        }
      }else{
        rules->active = FALSE;
      }
      return SUCCESS;
    }
  }

  event void EndCycleTimer.fired(){
    signal RoleScheduler.activeEnd();
    if (synched && missedCount > threshold){
      signal RoleScheduler.synchLost();
      search();
    }
  }

  command error_t SplitControl.stop(){
    call ActivityScheduler.stop();
    call StartCycleTimer.stop();
    call EndCycleTimer.stop();
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    if (isSchedule(msg)){
      //swap this out here and take pointer to pl.
      //If RAM is an issue, then we can do a memcpy of the payload to a
      //cx_schedule_t, immediately return this message, and post a task
      //to update the slot timing. 
      message_t* ret = schedMsg;
      schedMsg = msg;
      sched = pl;
      call ActivityScheduler.setSlotStart(plSlotNumber(msg),
        slotStart(msg));
      return ret;
    }else if (isOffer(msg)){
      if (needsAssignment){
        offeredSlot = slotNumber(msg);
        post requestSlot();
      }
      return msg;
    } else if (isAssignment(msg)){
      //Swap from pool, handle assignment
      message_t* ret = call Pool.get();
      if (ret){
        assignmentMsg = msg;
        post handleAssignment();
        return ret;
      }else{
        return msg;
      }
    }else {
      return signal Receive.receive(msg, pl, len);
    }
  }

  task void requestSlot(){
    if ((call Random.rand16() & 0x0F ) < sched->requestProb){
      //TODO: get message from pool
      //TODO: set slot number to offeredSlot
      //TODO: send it.
    }
  }

  task void handleAssignment(){
    //if WE are assigned, then record that this happened, clear
    //needsAssignment, etc.
    //return assignmentMsg to the pool.
    needsAssignment = FALSE;
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (needsAssignment){
      //not scheduled yet.
      return EOFF;
    }else{
      //TODO: set MD slot number to the next slot we own.
      //TODO: set TTL if not already set.
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS == error && isRequest(msg)){
      //TODO: put msg back into pool.
      //this was a request, now we're waiting for the response.
      waitingForAssignment = TRUE;
    } else {
      signal Send.sendDone(msg, error);
    }
  }

}
