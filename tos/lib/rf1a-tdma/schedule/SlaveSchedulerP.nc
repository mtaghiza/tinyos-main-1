module SlaveSchedulerP {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface Receive as AnnounceReceive;
  uses interface AMSend as RequestSend;
  uses interface Receive as ResponseReceive;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface CXPacketMetadata;
  uses interface CXPacket;
  uses interface Random;

  provides interface SlotStarted;

} implementation {
  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  message_t request_msg_internal;
  message_t* request_msg = &request_msg_internal;
  
  cx_schedule_t* schedule = NULL;
  uint8_t scheduleNum = INVALID_SCHEDULE_NUM;

  uint16_t firstIdleFrame = 0;
  uint16_t lastIdleFrame = 0;
  uint16_t mySlot = INVALID_SLOT;
  bool isSynched = FALSE;
  bool claimedLast = FALSE;

  uint16_t curSlot = INVALID_SLOT;
  uint16_t curFrame = INVALID_SLOT;

  enum {
    S_OFF = 0x00,
    S_LISTEN = 0x01,
    S_REQUESTING = 0x02,
    S_CONFIRM_WAIT = 0x03,
    S_READY = 0x05,
  }; 

  uint8_t state = S_OFF;

  uint16_t getSlot(uint16_t frameNum);

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  task void startListen(){
    state = S_LISTEN;
    call TDMAPhySchedule.setSchedule(call TDMAPhySchedule.getNow(),
      0, 
      1, 
      SCHED_INIT_SYMBOLRATE,
      TEST_CHANNEL,
      FALSE
      );
  }

  task void claimSlotTask();

  task void updateSchedule(){
    uint8_t sri = srIndex(schedule->symbolRate);
    isSynched = TRUE;
    //TODO: clock skew correction
    //TODO: why is originalFrameNum in the packet interface rather
    //than metadata?
    call TDMAPhySchedule.setSchedule(
      call CXPacketMetadata.getPhyTimestamp(schedule_msg) -
      sfdDelays[sri] - fsDelays[sri],
      call CXPacket.getOriginalFrameNum(schedule_msg) + call
      CXPacketMetadata.getReceivedCount(schedule_msg),
      schedule->framesPerSlot*schedule->slots,
      schedule->symbolRate,
      schedule->channel,
      isSynched
    );
    firstIdleFrame = (schedule->firstIdleSlot  * schedule->framesPerSlot);
    lastIdleFrame = (schedule->lastIdleSlot * schedule->framesPerSlot);

    //this indicates that we sent a request, but got no response.
    if (state == S_CONFIRM_WAIT){
      mySlot = INVALID_SLOT;
      state = S_LISTEN;
    }
    
    if (mySlot == INVALID_SLOT && state == S_LISTEN){
      state = S_REQUESTING;
      post claimSlotTask();
    }else if (state == S_REQUESTING){
      state = S_CONFIRM_WAIT;
    }
  }

  task void claimSlotTask(){
    uint8_t numValid;
    uint8_t i;
    error_t error;
    cx_request_t* request = call RequestSend.getPayload(request_msg,
      sizeof(cx_request_t));
//    printf_TMP("%s: slots ", __FUNCTION__);
    //pick a valid slot
    for(i = 0; i < MAX_ANNOUNCED_SLOTS; i++){
      if (schedule->availableSlots[i] != INVALID_SLOT){
//        printf_TMP("%u: %u ", i, schedule->availableSlots[i]); 
        numValid++;
      }
    }

//    printf_TMP("\r\n");
    mySlot = schedule->availableSlots[(call Random.rand16() % numValid)];

    //set up packet
    request->slotNumber = mySlot;
    printf_TMP("Claim %u\r\n", mySlot);
    //call RequestSend.send
    error = call RequestSend.send(call CXPacket.source(schedule_msg), 
      request_msg, 
      sizeof(cx_request_t));
    if (error != SUCCESS){
      printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
    }
  }

  event message_t* AnnounceReceive.receive(message_t* msg, void* pl, uint8_t len){
    message_t* ret = schedule_msg;
    schedule_msg = msg;
    schedule = (cx_schedule_t*)pl;
    post updateSchedule();
    return ret;
  }

  event void SubSplitControl.startDone(error_t error){ 
    post startListen();
  }

  event void SubSplitControl.stopDone(error_t error){ 
    signal SplitControl.stopDone(error);
  }

  event void FrameStarted.frameStarted(uint16_t frameNum){
    curFrame = frameNum;
    if (0 == (frameNum % call TDMARoutingSchedule.framesPerSlot())){
      printf_TMP("s %u\r\n", curFrame);
      curSlot = getSlot(frameNum);
      signal SlotStarted.slotStarted(curSlot);
    }
    //TODO: check for synch loss
  }

  event void RequestSend.sendDone(message_t* msg, error_t error){
    //now we're waiting for response
    state = S_REQUESTING;
  }

  task void startDoneTask(){
    signal SplitControl.startDone(SUCCESS);
  }

  event message_t* ResponseReceive.receive(message_t* msg, void* pl, uint8_t len){
    cx_response_t* response = (cx_response_t*)pl;
    if (response->slotNumber == mySlot){
      if (response->owner == TOS_NODE_ID){
        state = S_READY;
        //confirmed, hooray.
        printf_TMP("Confirmed @%u\r\n", mySlot);
        post startDoneTask();
      }else{
        mySlot = INVALID_SLOT;
        state = S_LISTEN;
        //contradicts us: somebody else claimed it.
        printf_TMP("Contradicted @%u, try again\r\n", mySlot);
        mySlot = INVALID_SLOT;
      }
    }
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

  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){ return 0;}
  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    return scheduleNum;
  }
  async event void TDMAPhySchedule.peek(message_t* msg, uint16_t frameNum, 
    uint32_t timestamp){}

  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return isSynched;
  }
  
  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return schedule->framesPerSlot;
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return schedule->maxRetransmit;
  }
  uint16_t getSlot(uint16_t frameNum){
    return frameNum / call TDMARoutingSchedule.framesPerSlot();
  }
  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    return getSlot(frameNum) == mySlot;
  }

  async command uint16_t TDMARoutingSchedule.maxDepth(){
    //TODO: should this be in the schedule announcement?
    return SCHED_MAX_DEPTH;
  }

  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return schedule->framesPerSlot - (frameNum % schedule->framesPerSlot);
  }

  command uint16_t TDMARoutingSchedule.currentFrame(){
    return curFrame;
  }

  command uint16_t TDMARoutingSchedule.getDefaultSlot(){
    return mySlot;
  }

  command uint16_t TDMARoutingSchedule.getNumSlots(){
    return schedule->slots;
  }

  command uint16_t SlotStarted.currentSlot(){ 
    return curSlot;
  }
   
}
