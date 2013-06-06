module CXActivitySchedulerP {
  uses interface Timer<T32Khz> as SlotTimer;
  uses interface Timer<T32Khz> as TXTimer;
  uses interface Timer<T32Khz> as RXTimer;

  uses interface CXLink;
  
  provides interface Send;
  uses interface Get<cx_schedule_t*>;

  provides interface SplitControl;
  
  provides interface ActivityScheduler;

} implementation {
  //search schedule: 
  // slotLength = tone + 1 packet
  // activeSlots = 1
  // numSlots = set for desired search duty cycle
  
  //wakeup schedule:
  // slotLength = tone + 1 packet
  // to guarantee waking up all nodes at depth i or lower:
  //   activeSlots = numSlots = search_numSlots*i
  
  //normal schedule:
  // activeSlots = dictated by network size
  // slotLength = tone + several packets
  // numSlots = f(slotLength, ipi)
  
  #define sched (call Get.get())

  command error_t ActivityScheduler.setSlotStart(
      uint16_t atSlotNumber, uint32_t t0, uint32_t dt){
    if (call SlotTimer.running()){
      call SlotTimer.stop();
    }
    slotNumber = atSlotNumber == 0 ? sched()->numSlots : (atSlotNumber - 1);
    call SlotTimer.startOneShotAt(t0, dt);
  }

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  event void SubSplitControl.startDone(error_t error){
    signal SplitControl.startDone();
  }

  event void SlotTimer.fired(){
    slotNumber = (slotNumber+1)%(sched()->numSlots);
    call SlotTimer.startOneShot(sched()->slotLength);

    if (txMsg && slotNumber(txMsg) == slotNumber){
      call CXLink.txTone();
    }else if (slotNumber <= sched()->activeSlots){
      call CXLink.rxTone();
    }else{
      call CXLink.sleep();
    }
  }

  event void CXLink.toneSent(){
    if (txMsg){
      call TXTimer.startOneShot(FRAMELEN_SLOW);
    }
  }

  event void CXLink.toneReceived(bool received){
    if (!received){
      call CXLink.sleep();
    }else{
      call RXTimer.startPeriodic(FRAMELEN_SLOW);
    }
  }
  
  //send pending message, if there is one (and there's enough time)
  event void TXTimer.fired(){
    if (txMsg && !sending && 
        (call SlotTimer.nextAlarm() - call TXTimer.now() > (FRAMELEN_SLOW*TTL))){
      call SubSend.send(txMsg);
      sending = TRUE;
    }else{
      call TXTimer.startOneShot(FRAMELEN_SLOW + TX_SLACK);
    }
  }

  event void SubSend.sendDone(){
    sending = FALSE;
    txMsg = NULL;
    signal Send.sendDone();
  }

  uint16_t slotNumber(message_t* msg){
    //TODO: pull slot number from metadata
    return 0;
  }

  uint16_t slotsFromNow(message_t* msg){
    //TODO: use current slot, cycle length, and slotNumber(msg) to
    //figure out how many slots away it is.
    return 0;
  }
  
  command error_t Send.send(message_t* msg, uint8_t len){
    if (txMsg == NULL){
      txMsg = msg;
    } else {
      if (slotsFromNow(msg) < slotsFromNow(txMsg)){
        signal Send.sendDone(txMsg, ERETRY);
        txMsg = msg;
      } else{
        return EBUSY;
      }
    }
    //TODO: handle acks-- should share TX/RXTimer (both synched up to
    //the same tone)
    //- the idea here is that a slot is activated if we tx or rx a
    //  tone. if we have a packet scheduled for this slot, we send it
    //  regardless of whether it's ack or data.
    return SUCCESS;
  }
  
  command error_t Send.cancel(message_t* msg){
    if (txMsg == msg && !sending){
      txMsg = NULL;
      return SUCCESS;
    }else{
      return FAIL;
    }
  }
}

