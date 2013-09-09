module CXSlaveP {
  provides interface SlotController;
  provides interface CTS[uint8_t ns];
  uses interface Get<probe_schedule_t*> as GetProbeSchedule;
  provides interface Get<am_addr_t> as GetRoot[uint8_t ns];
} implementation {
  am_addr_t masters[NUM_SEGMENTS] = {AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR};

  command am_addr_t GetRoot.get[uint8_t ns](){
    return masters[ns];
  }

  command am_addr_t SlotController.activeNode(){
    return AM_BROADCAST_ADDR;
  }
  command bool SlotController.isMaster(){
    return FALSE;
  }
  command bool SlotController.isActive(){
    return FALSE;
  }
  command uint8_t SlotController.bw(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->bw[ns];
  }
  command uint8_t SlotController.maxDepth(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->maxDepth[ns];
  }
  command uint32_t SlotController.wakeupLen(uint8_t ns){
    return (call GetProbeSchedule.get())->wakeupLen[ns];
  }
  command message_t* SlotController.receiveEOS(
      message_t* msg, cx_eos_t* pl){
    return msg;
  }
  command message_t* SlotController.receiveStatus(
      message_t* msg, cx_status_t *pl){
    return msg;
  }
  command void SlotController.endSlot(){
  }
  command void SlotController.receiveCTS(am_addr_t master, 
      uint8_t ns){
    masters[ns] = master;
    signal CTS.ctsReceived[ns]();
  }

  default event void CTS.ctsReceived[uint8_t ns](){
  }
}
