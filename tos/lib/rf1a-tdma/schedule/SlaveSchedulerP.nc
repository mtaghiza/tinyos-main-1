module SlaveSchedulerP {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface Receive as AnnounceReceive;
  uses interface AMSend as RequestSend;
  uses interface Receive as ResponseReceive;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

} implementation {
  enum {
    S_OFF = 0x00,
    S_LISTEN = 0x01,
    S_REQUESTING = 0x02,
    S_CONFIRM_WAIT = 0x03,
    S_READY = 0x05,
  }; 

  command error_t SplitControl.start(){
    return FAIL;
  }
  command error_t SplitControl.stop(){
    return FAIL;
  }
  event void SubSplitControl.startDone(error_t error){ }
  event void SubSplitControl.stopDone(error_t error){ }
  async event void FrameStarted.frameStarted(uint16_t frameNum){}

  event void RequestSend.sendDone(message_t* msg, error_t error){}
  event message_t* ResponseReceive.receive(message_t* msg, void* pl, uint8_t len){return msg;}
  event message_t* AnnounceReceive.receive(message_t* msg, void* pl, uint8_t len){return msg;}

  //TODO: wiring for splitcontrol, (I guess)
  
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

  async event bool TDMAPhySchedule.isInactive(uint16_t frameNum){
    //TODO: return true if frameNum is between firstIdle and lastIdle,
    //or is in an unannounced+unassigned slot.
    return TRUE;
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, uint16_t frameNum){}
  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){ return 0;}
  async event uint8_t TDMAPhySchedule.getScheduleNum(){
    //TODO: return current schedule num
    return 0;
  }
  async event void TDMAPhySchedule.peek(message_t* msg, uint16_t frameNum, 
    uint32_t timestamp){}
  
  //TODO: fill 'em in
  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return 0;
  }
  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return FALSE;
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return 0;
  }
  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    return FALSE;
  }
  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return 0;
  }
   
}
