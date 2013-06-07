module CXSlaveP {
  provides interface Get<cx_schedule_t*>;
  uses interface ActivityScheduler;
  
  provides interface SplitControl;

  provides interface RoleSchedule;
  uses interface Timer<T32Khz> as CycleTimer;
  uses interface Timer<T32Khz> as EndCycleTimer;
} implementation {

  //TODO initialize search schedule 
  cx_schedule_t searchSchedule = {
    //tone + 1 flood
    .slotLength = 2 + SEARCH_MAXDEPTH, 
    //only check for 1 slot in the cycle
    .activeSlots = 1,
    //set for desired search DC
    .numSlots = SEARCH_NUMSLOTS  
  };
  cx_schedule_t* sched;
  
  event void StartCycleTimer.fired(){
    call ActivityScheduler.setSlotStart(0,
      call CycleTimer.gett0(), call CycleTimer.getdt());
    call EndCycleTimer.startOneShotAt(
      call CycleTimer.gett0(), 
      call CycleTimer.getdt() + sched->activeSlots*sched->slotLength);
  }

  event void EndCycleTimer.fired(){
    signal RoleScheduler.activeEnd();
    if (synched && missedCount > threshold){
      signal RoleScheduler.synchLost();
      search();
    }
  }
  
  void search(){
    call ActivityScheduler.stop();
    sched = searchSchedule;
    call StartCycleTimer.startPeriodicAt(
      call StartCycleTimer.getNow() - sched->numSlots * sched->slotLength,
      sched->numSlots * sched->slotLength);
  }

  command error_t SplitControl.start(){
    search();
  }

  command error_t SplitControl.stop(){
    call ActivityScheduler.stop();
    call StartCycleTimer.stop();
    call EndCycleTimer.stop();
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    //swap this out here and take pointer to pl.
    //If RAM is an issue, then we can do a memcpy of the payload to a
    //cx_schedule_t, immediately return this message, and post a task
    //to update the slot timing. 
    if (isSchedule(msg)){
      message_t* ret = schedMsg;
      schedMsg = msg;
      sched = pl;
      call ActivityScheduler.setSlotStart(plSlotNumber(msg),
        slotStart(msg));
      if (needsAssignment){
        post requestSlot();
      }
      return ret;
    }else if (isAssignment(msg)){
      //Swap from pool, handle assignment
      message_t* ret = call Pool.get();
      if (ret){
        assignmentMsg = msg;
        post handleAssignment();
        return ret;
      }else{
        return msg;
      }
    }
  }

  task void requestSlot(){
    //pick slot from sched, set slotNumber on it, and 
    //SubSend.send the request packet.
  }

  task void handleAssignment(){
    //if WE are assigned, then record that this happened, clear
    //needsAssignment, etc.
    //return assignmentMsg to the pool.
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (needsAssignment){
      //not scheduled yet.
      return EOFF;
    }else{
      //TODO: set MD slot number to the next slot we own.
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (needsAssignment){
      //this was a request, now we're waiting for the response.
      waitingForAssignment = TRUE;
    } else {
      signal Send.sendDone(msg, error);
    }
  }

  event void ActivityScheduler.slotStarted(){
    if (waitingForAssignment && needsAssignment){
      waitingForAssignment = FALSE;
      post requestSlot();
    }
  }

}
