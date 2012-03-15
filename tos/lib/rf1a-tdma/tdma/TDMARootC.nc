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
    return SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return SubSplitControl.stop();
  }

  task void announceSchedule(){
    error_t error;
    call CXPacket.setType(schedule_msg, CX_TYPE_SCHEDULE);
    error = call Send.send(schedule_msg);
    if (SUCCESS != error){
      printf("announce schedule: %s\r\n", decodeError(error));
    }
  }

  event void Send.sendDone(message_t* msg, error_t error){
    if (SUCCESS == error){
      post announceSchedule();
    } else {
      printf("send done: %s \r\n", decodeError);
    }
  }

  event void SubSplitControl.startDone(error_t error){
    if (SUCCESS == error){
      error = call TDMARootControl.setSchedule(DEFAULT_TDMA_FRAME_LEN,
        DEFAULT_TDMA_FW_CHECK_LEN, 8, 8, 2, 2, schedule_msg);
      if (SUCCESS == error){
        post announceSchedule();
      }
    }
    signal SplitControl.startDone(error);
  }

  event bool TDMARootControl.isRoot(){
    return TRUE;
  }

}
