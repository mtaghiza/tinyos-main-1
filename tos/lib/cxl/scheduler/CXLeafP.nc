module CXLeafP {
  provides interface SlotController;
  provides interface CTS;
} implementation {

  command am_addr_t SlotController.activeNode(){
    return AM_BROADCAST_ADDR;
  }
  command bool SlotController.isMaster(){
    return FALSE;
  }
  command bool SlotController.isActive(){
    return FALSE;
  }
  command uint8_t SlotController.bw(){
    return CX_DEFAULT_BW;
  }
  command uint8_t SlotController.maxDepth(){
    return CX_MAX_DEPTH;
  }
  command uint32_t SlotController.wakeupLen(){
    return CX_WAKEUP_LEN;
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
  command void SlotController.receiveCTS(){
    signal CTS.ctsReceived();
  }
}
