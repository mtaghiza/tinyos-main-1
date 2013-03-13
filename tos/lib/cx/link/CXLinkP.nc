
 #include "CXLink.h"
module CXLinkP {
  provides interface SplitControl;
  provides interface CXRequestQueue;

  uses interface Pool<cx_request_t>;
  uses interface Queue<cx_request_t*>;

  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface DelayedSend;
  uses interface Rf1aPhysicalMetadata;

  uses interface Alarm<TMicro, uint32_t> as TransmitAlarm;
  uses interface Timer<T32khz, uint32_t> as FrameTimer;
  uses interface GpioCapture as SynchCapture;
} implementation {
  //TODO: require some command to adjust frame timing
  
  uint32_t frameNum = 0;

  //keep count of how many outstanding requests rely on the
  //alarm so that we can duty cycle it when it's not in use.
  uint8_t alarmUsers = 0;
  
  //value to be signaled up at request completion
  error_t requestError;
  uint32_t handledFrame;
  cx_request_t* nextRequest = NULL;

  command uint32_t CXRequestQueue.nextFrame(){
    return frameNum;
  }

  task void requestHandled(){
    switch(nextRequest -> requestType){
      case RT_SLEEP:
        signal CXRequestQueue.sleepHandled(requestError, handledFrame);
        break;
      case RT_WAKEUP:
        signal CXRequestQueue.wakeupHandled(requestError, handledFrame);
        break;
      case RT_TX:
        signal CXRequestQueue.sendHandled(requestError, handledFrame,
          sfdCapture, nextRequest->msg);
        break;
      case RT_RX:
        signal CXRequestQueue.receiveHandled(requestError,
          handledFrame, didReceive, nextRequest->msg);
        break;
      default:
        //shouldn't happen
        break;
    }
    call Pool.put(nextRequest);
    post readyNextRequest();
  }

  event void FrameTimer.fired(){
    frameNum ++;
    if (nextRequest != NULL){
      if (nextRequest->baseFrame + nextRequest -> frameOffset == frameNum){
        switch (nextRequest -> requestType){
          case RT_SLEEP:
            //if radio is active, shut it off.
            requestError = call Rf1aPhysical.sleep();
            handledFrame = frameNum;
            post requestHandledTask();
            break;
          case RT_WAKEUP:
            requestError = call RF1aPhysical.resumeIdleMode(FALSE);
            //if radio is off, turn it on (idle)
            handledFrame = frameNum;
            post requestHandledTask();
            break;
          case RT_TX:
            //TODO: set TransmitAlarm
            //TODO: enable RE GDO capture 
            //TODO: configure radio/load in start of packet
            break;
          case RT_RX:
            //TODO: set timeout alarm
            //TODO: enable RE GDO capture 
            //TODO: configure radio/provide rx buffer.
            break;
          default:
            //should not happen.
        }
      }
    }
  }

  task void readyNextRequest(){
    //TODO: if it requires adjusting preparation time, go ahead and do
    //so.
  }
  
  cx_request_t* newRequest(uint32_t baseFrame, 
      int32_t frameOffset, request_type_t requestType){
    cx_request_t* r = call Pool.get();
    //TODO: should probably validate that this isn't in the past and
    //  return an error if it can't be scheduled.
    if (r != NULL){
      r->requestedTime = call FrameTimer.getNow();
      r->baseFrame = baseFrame;
      r->requestType = requestType;
      r->frameOffset = frameOffset;
      r->useTsMicro = FALSE;
      r->msg = NULL;
    }
    return r;
  }

  void enqueue(cx_request_t* r){
    if ( r->useTsMicro){
      alarmUsers++;
    }
    if (requestLeq(r, nextRequest)){
      //r supersedes: re-enqueue nextRequest, keep this dude out.
      if (nextRequest != NULL){
        call Queue.enqueue(nextRequest);
      }
      nextRequest = r;
      post readyNextRequest();
    }else{
      call Queue.enqueue(r);
    }
  }

  command error_t CXRequestQueue.requestReceive(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration,
      message_t* msg){
    return FAIL;
  }

  default event void CXRequestQueue.receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive, 
    uint32_t microRef, message_t* msg){}

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    message_t* msg);
    return FAIL;

  default event void CXRequestQueue.sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg){}

  command error_t CXRequestQueue.requestSleep(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_SLEEP);
    if (r != NULL){
      enqueue(r);
      return SUCCESS;
    } else{ 
      return ENOMEM;
    }
  }

  default event void error_t CXRequestQueue.sleepHandled(error_t error, uint32_t atFrame){ }

  command error_t CXRequestQueue.requestWakeup(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_WAKEUP);
    if (r != NULL){
      enqueue(r);
      return SUCCESS;
    } else{ 
      return ENOMEM;
    }
  }

  default event void error_t CXRequestQueue.wakeupHandled(error_t error, uint32_t atFrame){}

  command error_t SplitControl.start(){
    return call Resource.request();
  }

  event void Resource.granted(){
    call FrameTimer.startPeriodic(FRAMELEN_32KHZ);
    signal SplitControl.startDone(SUCCESS);
  }

  task void signalStopDone(){
    signal SplitControl.stopDone(SUCCESS);
  }
  command error_t SplitControl.stop(){
    call FrameTimer.stop();
    post signalStopDone();
    return call Resource.release();
  }

}
