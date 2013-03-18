module CXSlaveSchedulerP{
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface CXRequestQueue;
} implementation {
  message_t msg_internal;
  message_t* schedMsg;

  command error_t SplitControl.start(){
    error_t error = call SubSplitControl.start();
    return error;
  }

  task void awaitSchedule(){
    error_t error = call CXRequestQueue.requestReceive(
        call CXRequestQueue.nextFrame(), 1,
        FALSE, 0,
        RX_MAX_WAIT, NULL, schedMsg);
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      post awaitSchedule();
    }
  }

  event void CXRequestQueue.receiveHandled(){
    //TODO: check for whether or not this is a schedule
  }
}
