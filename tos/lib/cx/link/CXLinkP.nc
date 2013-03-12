
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
  uint8_t alarmUsers = 0;
  cx_request_t* nextRequest = NULL;

  event void FrameTimer.fired(){
    frameNum ++;
    if (nextRequest != NULL){
      if (nextRequest->baseFrame + nextRequest -> frameOffset == frameNum){
        switch (nextRequest -> requestType){
          case RT_SLEEP:
            //if radio is active, shut it off.
            break;
          case RT_WAKEUP:
            //if radio is off, turn it on (idle)
            break;
          case RT_TX:
            //set TransmitAlarm
            //configure radio/load in start of packet
            break;
          case RT_RX:
            //configure radio/provide rx buffer.
            break;
          default:
            //should not happen.
        }
      }
    }
  }

  command uint32_t CXRequestQueue.nextFrame(){
    return frameNum;
  }

  task void readyNextRequest(){
    //TODO: if it requires adjusting preparation time, go ahead and do
    //so.
  }
  
  cx_request_t* newRequest(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = call Pool.get();
    if (r != NULL){
      r->requestedTime = call FrameTimer.getNow();
      r->baseFrame = baseFrame;
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
    return FAIL;
  }

  default event void error_t CXRequestQueue.sleepHandled(error_t error, uint32_t atFrame){ }

  command error_t CXRequestQueue.requestWakeup(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(baseFrame, frameOffset);
    if (r != NULL){
      r->requestType = RT_WAKEUP;
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
