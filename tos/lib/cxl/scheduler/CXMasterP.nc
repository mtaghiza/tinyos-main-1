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
    .numSlots = SEARCH_NUMSLOTS,
    .beaconInterval = 1,
    .beaconOffset = 0,
  };

  //"normal" schedule:
  // activeSlots = dictated by network size
  // slotLength = tone + several packets, at least.
  // numSlots = f(slotLength, ipi)
  cx_schedule_t activeSchedule ={
    .slotLength  =  DEFAULT_SLOTLENGTH,
    .activeSlots =  DEFAULT_ACTIVESLOTS,
    .numSlots    =  DEFAULT_NUMSLOTS,
    .beaconInterval = CX_BEACON_INTERVAL,
    .beaconOffset = 1
  };


  cx_schedule_t* sched = &wakeupSchedule;

  command error_t RoleScheduler.setCycle(uint32_t t0, 
      uint16_t uplinkActive, uint16_t downlinkActive, 
      uint16_t cycleLen){
    //The layer above determines cycle len.
    // - base stations will self-define this.
    // - routers will get this from base station beacons.
    call ActivityScheduler.setSlotStart(0, t0, 0);
  }

  command error_t SplitControl.start(){
  }

  event void StartCycleTimer.fired(){
    
  }
  
  message_t* evictedMessage;
  event void SubSend.sendDone(message_t* msg, error_t error){
    if (error == ERETRY){
      evictedMessage = msg;
    } else if (error == SUCCESS && evictedMessage != NULL){
      if (msg == evictedMessage){
        evictedMessage = NULL;
      } else {
        post retryEvicted();
      }
    }
    if (isAssignment(msg)){
      //pass
    } else if(isSchedule(msg)){
      //pass
    }else{
      signal Send.sendDone(msg, error);
    }
  }

  command error_t Send.send(message_t* msg, error_t error){
    //TODO: set slot number to owned slot, set TTL if not already set.
    return call SubSend.send(msg, error);
  }
  
  /**
   * Give the activity scheduler its orders: send beacon if needed,
   * otherwise set the channel to match mode (up or down).
   * It should be possible to make this role-agnostic.
   */
  event void ActivitySchedule.slotStarted(uint16_t slotNumber, 
      cx_slot_rules_t* rules){
    if ((slotNumber-sched->beaconOffset) % sched->beaconInterval == 0){
      setSlotNumber(schedMsg, slotNumber);
      call SubSend.send(sched, sizeof(cx_schedule_t));
      rules -> active = TRUE;
      rules -> txTone = CX_BEACON_CHANNEL;
    }else {
      rules -> active = !(slotNumber > sched->uplinkActive 
        && slotNumber < sched->downlinkActive);
      if (rules->active){
        rules->channel = (slotNumber <= sched->uplinkActive)?
          sched->uplinkChannel : sched->downlinkChannel;
      }
    }
  }

}
