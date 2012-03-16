module TDMARootC{
  provides interface SplitControl;

  uses interface Send;
  uses interface TDMARootControl;
  uses interface SplitControl as SubSplitControl;
} implementation {
  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;
  cx_schedule_t* schedule_pl;

  command error_t SplitControl.start(){
    printf("tdmaRoot: sc.start\r\n");
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  task void announceSchedule(){
    error_t error;
    error = call Send.send(schedule_msg, sizeof(cx_schedule_t));
    if (SUCCESS != error){
      printf("announce schedule: %s\r\n", decodeError(error));
    }
  }

  event void Send.sendDone(message_t* msg, error_t error){
    if (SUCCESS == error){
      post announceSchedule();
    } else {
      printf("send done: %s \r\n", decodeError(error));
    }
  }
  
  #if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
  #define TDMA_ROOT_INACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT) 
  #else
  #error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
  #endif
  

  event void SubSplitControl.startDone(error_t error){
    if (SUCCESS == error){
      error = call TDMARootControl.setSchedule(DEFAULT_TDMA_FRAME_LEN,
        DEFAULT_TDMA_FW_CHECK_LEN, 
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES, 
        TDMA_ROOT_FRAMES_PER_SLOT, 
        TDMA_MAX_RETRANSMIT, 
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID, 
        schedule_msg);
      if (SUCCESS == error){
        post announceSchedule();
      }
    }
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SubSplitControl.stopDone(error);
  }

  event bool TDMARootControl.isRoot(){
    return TRUE;
  }

}
