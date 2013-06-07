module CXMasterP {
  provides interface RoleScheduler;
} implementation {
  //wakeup schedule:
  // slotLength = tone + 1 packet
  // to guarantee waking up all nodes at depth i or lower:
  //   activeSlots = numSlots = search_numSlots*i
  cx_schedule_t wakeupSchedule = {
    .slotLength = 2 + SEARCH_MAXDEPTH,
    .activeSlots = SEARCH_NUMSLOTS,
    .numSlots = SEARCH_NUMSLOTS
  };

  //"normal" schedule:
  // activeSlots = dictated by network size
  // slotLength = tone + several packets, at least.
  // numSlots = f(slotLength, ipi)
  cx_schedule_t activeSchedule ={
    .slotLength  =  DEFAULT_SLOTLENGTH,
    .activeSlots =  DEFAULT_ACTIVESLOTS,
    .numSlots    =  DEFAULT_NUMSLOTS,
  };

  cx_schedule_t* sched = &wakeupSchedule;

  command error_t RoleScheduler.setCycle(uint32_t t0, 
      uint16_t maxActive, uint16_t cycleLen){
    //The layer above determines cycle len.
    // - base stations will self-define this.
    // - routers will use the slave cycle length to match this and
    //   coordinate the start times as needed to prevent overlap.
  }

  command error_t SplitControl.start(){
  }

  event void StartCycleTimer.fired(){
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (isAssignment(msg)){
      //pass
    } else if(isSchedule(msg)){
      //pass
    }else{
      signal Send.sendDone(msg, error);
    }
  }

  command Send.send(message_t* msg, error_t error){
    //set slot number to owned slot, set TTL if not already set.
    call SubSend.send(msg, error);
  }
  

}
