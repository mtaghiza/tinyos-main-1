module CXMasterP {
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

  cx_schedule_t* sched;

  //normal schedule:
  // activeSlots = dictated by network size
  // slotLength = tone + several packets
  // numSlots = f(slotLength, ipi)

  command error_t SplitControl.start(){
    //use wakeupSchedule
  }

  event void StartCycleTimer.fired(){
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
  }

}
