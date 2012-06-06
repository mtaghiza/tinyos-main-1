module RouterSchedulerP {
  provides interface FrameStarted[uint8_t clientId];
  uses interface FrameStarted as SubFrameStarted;

  provides interface SplitControl as AppSplitControl;
  uses interface SplitControl as MetaSplitControl[uint8_t clientId];
  provides interface SplitControl as MetaSubSplitControl[uint8_t clientId];
  uses interface SplitControl as SubSplitControl;
  

  //TODO: will probably have to do the same 4-interface malarkey with
  //this, too.
  provides interface TDMARoutingSchedule;
  uses interface TDMARoutingSchedule 
    as SubTDMARoutingSchedule[uint8_t clientId];
   
  provides interface TDMAPhySchedule[uint8_t clientId];
  uses interface TDMAPhySchedule as SubTDMAPhySchedule;
} implementation {
  command error_t AppSplitControl.start(){
    printf_TMP("AppSC.start\r\n");
    return call MetaSplitControl.start[CX_SCHEDULER_MASTER]();
  }

  command error_t AppSplitControl.stop(){
    return call MetaSplitControl.stop[CX_SCHEDULER_MASTER]();
  }

  event void MetaSplitControl.startDone[uint8_t clientId](error_t error){
    signal AppSplitControl.startDone(error);
  }

  event void MetaSplitControl.stopDone[uint8_t clientId](error_t error){
    signal AppSplitControl.stopDone(error);
  }

  command error_t MetaSubSplitControl.start[uint8_t clientId](){
    return call SubSplitControl.start();
  }
  command error_t MetaSubSplitControl.stop[uint8_t clientId](){
    return call SubSplitControl.stop();
  }
  event void SubSplitControl.startDone(error_t error){
    signal MetaSubSplitControl.startDone[CX_SCHEDULER_MASTER](error);
  }
  event void SubSplitControl.stopDone(error_t error){
    signal MetaSubSplitControl.stopDone[CX_SCHEDULER_MASTER](error);
  }

  default event void MetaSubSplitControl.startDone[uint8_t clientId](error_t error){}
  default event void MetaSubSplitControl.stopDone[uint8_t clientId](error_t error){}


  default command error_t MetaSplitControl.start[uint8_t clientId](){
    return FAIL;
  }

  default command error_t MetaSplitControl.stop[uint8_t clientId](){
    return FAIL;
  }


  command error_t TDMAPhySchedule.setSchedule[uint8_t clientId](uint32_t startAt,
      uint16_t atFrameNum, 
      uint16_t totalFrames, 
      uint8_t symbolRate,
      uint8_t channel, 
      bool isSynched){
    return call SubTDMAPhySchedule.setSchedule(startAt, atFrameNum,
      totalFrames, symbolRate, channel, isSynched);
  } 
  async command uint32_t TDMAPhySchedule.getNow[uint8_t clientId](){
    return call SubTDMAPhySchedule.getNow();
  }

  async event bool SubTDMAPhySchedule.isInactive(uint16_t frameNum){
    return signal TDMAPhySchedule.isInactive[CX_SCHEDULER_MASTER](frameNum);
  }
  
  async event void SubTDMAPhySchedule.frameStarted(uint32_t startTime, uint16_t frameNum){
    signal TDMAPhySchedule.frameStarted[CX_SCHEDULER_MASTER](startTime,
    frameNum);
  }
  async event int32_t SubTDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){ 
    return signal TDMAPhySchedule.getFrameAdjustment[CX_SCHEDULER_MASTER](frameNum);
  }
  async event uint8_t SubTDMAPhySchedule.getScheduleNum(){
    return signal TDMAPhySchedule.getScheduleNum[CX_SCHEDULER_MASTER]();
  }
  async event void SubTDMAPhySchedule.peek(message_t* msg, uint16_t frameNum, 
    uint32_t timestamp){
    signal TDMAPhySchedule.peek[CX_SCHEDULER_MASTER](msg, frameNum,
      timestamp);
  }

  default async event bool TDMAPhySchedule.isInactive[uint8_t clientId](uint16_t frameNum){ return TRUE;}
  default async event void TDMAPhySchedule.frameStarted[uint8_t clientId](uint32_t startTime, uint16_t frameNum){ }
  default async event int32_t TDMAPhySchedule.getFrameAdjustment[uint8_t clientId](uint16_t frameNum){ return 0; }
  default async event uint8_t TDMAPhySchedule.getScheduleNum[uint8_t clientId](){ return 0; }
  default async event void TDMAPhySchedule.peek[uint8_t clientId](message_t* msg, uint16_t frameNum, uint32_t timestamp){ }
  

  async event void SubFrameStarted.frameStarted(uint16_t frameNum){
    signal FrameStarted.frameStarted[CX_SCHEDULER_MASTER](frameNum);
  }

  async command uint16_t TDMARoutingSchedule.framesPerSlot(){
    return call SubTDMARoutingSchedule.framesPerSlot[CX_SCHEDULER_MASTER]();
  }

  async command bool TDMARoutingSchedule.isSynched(uint16_t frameNum){
    return call SubTDMARoutingSchedule.isSynched[CX_SCHEDULER_MASTER](frameNum);
  }

  async command uint8_t TDMARoutingSchedule.maxRetransmit(){
    return call SubTDMARoutingSchedule.maxRetransmit[CX_SCHEDULER_MASTER]();
  }

  async command bool TDMARoutingSchedule.ownsFrame(uint16_t frameNum){
    return call SubTDMARoutingSchedule.ownsFrame[CX_SCHEDULER_MASTER](frameNum);
  }

  async command uint16_t TDMARoutingSchedule.framesLeftInSlot(uint16_t frameNum){
    return call SubTDMARoutingSchedule.framesLeftInSlot[CX_SCHEDULER_MASTER](frameNum);
  }

  default async event void FrameStarted.frameStarted[uint8_t clientId](uint16_t frameNum){}
  default async command uint16_t SubTDMARoutingSchedule.framesPerSlot[uint8_t clientId](){ return 0; }
  default async command bool SubTDMARoutingSchedule.isSynched[uint8_t clientId](uint16_t frameNum){return FALSE;}
  default async command uint8_t SubTDMARoutingSchedule.maxRetransmit[uint8_t clientId](){ return 0;}
  default async command bool SubTDMARoutingSchedule.ownsFrame[uint8_t clientId](uint16_t frameNum){ return FALSE;}
  default async command uint16_t SubTDMARoutingSchedule.framesLeftInSlot[uint8_t clientId](uint16_t frameNum){ return 0;}
}
