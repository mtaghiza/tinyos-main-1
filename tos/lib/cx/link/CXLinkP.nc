
 #include "CXLink.h"
module CXLinkP {
  provides interface SplitControl;
  provides interface CXRequestQueue;

  uses interface Pool<cx_request_t>;
  uses interface Queue<cx_request_t*>;
  provides interface Compare<cx_request_t*>;

  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface DelayedSend;
  uses interface Rf1aPhysicalMetadata;

  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface Timer<T32khz> as FrameTimer;
  uses interface GpioCapture as SynchCapture;

  uses interface Msp430XV2ClockControl;

} implementation {
  uint32_t lastFrameNum = 0;
  uint32_t lastFrameTime = 0;

  //keep count of how many outstanding requests rely on the
  //alarm so that we can duty cycle it when it's not in use.
  uint8_t alarmUsers = 0;
  //keep track of the last time the fast timer was started (so we can
  //detect cases where timing state is lost)
  uint32_t lastMicroStart = 0xFFFFFFFF;
  
  //value to be signaled up at request completion
  error_t requestError;
  uint32_t handledFrame;
  bool didReceive;
  cx_request_t* nextRequest = NULL;

  //Timestamping/transmit fragmentation
  uint8_t* tx_pos;
  uint8_t tx_len;

  //async-context variables/mirrors
  error_t aRequestError;
  request_type_t aNextRequestType;
  uint32_t aSfdCapture;
  bool asyncHandled = FALSE;

  //forward declarations
  task void readyNextRequest();
  error_t validateRequest(cx_request_t* r);
  
  void updateLastFrameNum(){
    //this should be safe from integer wrap
    uint32_t now = call FrameTimer.getNow();
    uint32_t elapsedTime = now - lastFrameTime;
    uint32_t elapsedFrames = elapsedTime/FRAMELEN_32K;
    lastFrameTime += (elapsedFrames*FRAMELEN_32K);
    lastFrameNum += elapsedFrames;
  }

  command uint32_t CXRequestQueue.nextFrame(){
    updateLastFrameNum();
    return lastFrameNum + 1;
  }


  task void requestHandled(){
    //if the request finished in the async context, need to copy
    //results back to the task context
    uint32_t sfdCapture;
    atomic{
      if (asyncHandled){
        sfdCapture = aSfdCapture;
        requestError = aRequestError;
      }
      asyncHandled = FALSE;
    }
    switch(nextRequest -> requestType){
      case RT_FRAMESHIFT:
        signal CXRequestQueue.frameShiftHandled(requestError,
          handledFrame);
        break;
      case RT_SLEEP:
        signal CXRequestQueue.sleepHandled(requestError, handledFrame);
        break;
      case RT_WAKEUP:
        signal CXRequestQueue.wakeupHandled(requestError, handledFrame);
        break;
      case RT_TX:
        signal CXRequestQueue.sendHandled(requestError, handledFrame,
          sfdCapture, nextRequest->msg);
        sfdCapture = 0;
        break;
      case RT_RX:
        signal CXRequestQueue.receiveHandled(requestError,
          handledFrame, didReceive, sfdCapture, nextRequest->msg);
        sfdCapture = 0;
        break;
      default:
        //shouldn't happen
        break;
    }
    if (nextRequest->useTsMicro){
      alarmUsers --;
    }
    if (alarmUsers == 0){
      call Msp430XV2ClockControl.stopMicroTimer();
    }

    call Pool.put(nextRequest);
    if (! call Queue.empty()){
      nextRequest = call Queue.dequeue();
    }
    post readyNextRequest();
  }

  event void FrameTimer.fired(){
    updateLastFrameNum();
    if (nextRequest != NULL){
      uint32_t targetFrame = nextRequest->baseFrame + nextRequest -> frameOffset; 
      if (targetFrame == lastFrameNum){
        printf("handle %lu @ %lu\r\n", 
          lastFrameNum, 
          call FrameTimer.gett0() + call FrameTimer.getdt());
        switch (nextRequest -> requestType){
          case RT_FRAMESHIFT:
            lastFrameTime += nextRequest->frameShift;
            handledFrame = lastFrameNum;
            requestError = SUCCESS;
            post requestHandled();
            break;
          case RT_SLEEP:
            //if radio is active, shut it off.
            requestError = call Rf1aPhysical.sleep();
            handledFrame = lastFrameNum;
            post requestHandled();
            break;
          case RT_WAKEUP:
            requestError = call Rf1aPhysical.resumeIdleMode(FALSE);
            //if radio is off, turn it on (idle)
            handledFrame = lastFrameNum;
            post requestHandled();
            break;
          case RT_TX:
            if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
              call Msp430XV2ClockControl.startMicroTimer();
              lastMicroStart = lastFrameTime;
            }
            requestError = call Rf1aPhysical.startTransmission(FALSE,
            TRUE);
            if (SUCCESS == requestError){
              atomic{
                tx_pos = (uint8_t*)nextRequest -> msg;
                aSfdCapture = 0;
                aRequestError = SUCCESS;
                //TODO: TX tx_len from nextRequest->msg metadata
                //TODO: TX CX link header setup
                //TODO: TIME timestamping setup
              }
              requestError = call Rf1aPhysical.send(tx_pos, tx_len, RF1A_OM_IDLE);
            }
            if (SUCCESS != requestError){
              post requestHandled();
            }
            break;
          case RT_RX:
            if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
              call Msp430XV2ClockControl.startMicroTimer();
              lastMicroStart = lastFrameTime;
            }
            requestError = FAIL;
            //TODO: RX set timeout alarm
            //TODO: RX enable RE GDO capture 
            //TODO: RX configure radio/provide rx buffer.
            post requestHandled();
            break;
          default:
            //should not happen.
        }
      }else if (targetFrame < lastFrameNum){
        //we have missed the intended frame. signal handled
        requestError = FAIL;
        post requestHandled();
      }else if (targetFrame > lastFrameNum){
        //shouldn't happen. re-doing readyNextRequest should work it
        //out. 
        call Queue.enqueue(nextRequest);
        nextRequest = call Queue.dequeue();
        post readyNextRequest();
      }
    }
  }

  task void readyNextRequest(){
    //if request is not valid, we need to signal its handling
    //  and pull the next one from the queue.
    error_t err = validateRequest(nextRequest);
    if (SUCCESS != err){
      requestError = err;
      post requestHandled();
    }else{
      uint32_t targetFrame = nextRequest -> baseFrame + nextRequest->frameOffset;
      uint32_t dt = (targetFrame - lastFrameNum)*FRAMELEN_32K;

      //TODO: FIXME if the request requires additional preparation time, go ahead and do
      //so: this slack should be stored so that when frametimer fires,
      //  we can account for it.
      call FrameTimer.startOneShotAt(lastFrameTime, dt);
    }

  }

  error_t validateRequest(cx_request_t* r){
    //event in the past? I guess we were busy.
    if (r->baseFrame + r->frameOffset < call CXRequestQueue.nextFrame()){
      return EBUSY;

    //micro timer required but it's either off or has been stopped
    //since the request was made
    }else if(r->useTsMicro && 
      (( ! call Msp430XV2ClockControl.isMicroTimerRunning()) 
         || (lastMicroStart > r->requestedTime))){
      return EINVAL;
    }
    return SUCCESS;
  }
  
  cx_request_t* newRequest(uint32_t baseFrame, 
      int32_t frameOffset, request_type_t requestType){
    cx_request_t* r = call Pool.get();
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

  command error_t CXRequestQueue.requestFrameShift(uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_FRAMESHIFT);
    if (r != NULL){
      error_t error = validateRequest(r);
      if (SUCCESS == error){
        r->frameShift = frameShift;
        enqueue(r);
      }
      return error;
    } else{ 
      return ENOMEM;
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
    uint32_t atFrame, bool didReceive_, 
    uint32_t microRef, message_t* msg){}

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    message_t* msg){
    return FAIL;
  }

  default event void CXRequestQueue.sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg){}

  command error_t CXRequestQueue.requestSleep(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_SLEEP);
    if (r != NULL){
      error_t error = validateRequest(r);
      if (SUCCESS == error){
        enqueue(r);
      }
      return error;
    } else{ 
      return ENOMEM;
    }
  }

  default event void CXRequestQueue.sleepHandled(error_t error, uint32_t atFrame){ }

  command error_t CXRequestQueue.requestWakeup(uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_WAKEUP);
    if (r != NULL){
      error_t error = validateRequest(r);
      if (SUCCESS == error){
        enqueue(r);
      }
      return error;
    } else{ 
      return ENOMEM;
    }
  }

  default event void CXRequestQueue.wakeupHandled(error_t error, uint32_t atFrame){}

  command error_t SplitControl.start(){
    if (call Resource.isOwner()){
      return EALREADY;
    }else{
      return call Resource.request();
    }
  }

  event void Resource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  task void signalStopDone(){
    signal SplitControl.stopDone(SUCCESS);
  }
  command error_t SplitControl.stop(){
    if (! call Resource.isOwner()){
      return EALREADY;
    }else{
      post signalStopDone();
      return call Resource.release();
    }
  }

  command bool Compare.leq(cx_request_t* l, cx_request_t* r){
    return requestLeq(l, r);
  }

  async event void SynchCapture.captured(uint16_t time){
    uint32_t ft = call FastAlarm.getNow();
    //overflow detected: assumes that 16-bit capture time has
    //  overflowed at most once before this event runs
    if (time > (ft & 0x0000ffff)){
      ft  -= 0x00010000;
    }
    //expand to 32 bits
    aSfdCapture = (ft & 0xffff0000) | time;
    //TODO: TIME post task to set timestamp
    //TODO: RX extend/cancel micro alarm (frame-wait)
    call SynchCapture.disable();

    asyncHandled = TRUE;
  }

  task void signalFastAlarm(){
    atomic signal FastAlarm.fired();
  }

  event void DelayedSend.sendReady(){
    if (nextRequest->useTsMicro){
      int32_t dt = (nextRequest->frameOffset)*FRAMELEN_6_5M;
      uint32_t t0 = nextRequest->tsMicro;
      //TODO: FIXME Wrapping logic/signedness issues? could mandate that
      //  frameOffset is always non-negative, that could simplify
      //  matters.
      if ( t0 + dt < call FastAlarm.getNow() + MIN_FASTALARM_SLACK ){
        //not enough time, so fail.
        requestError = FAIL;
      }else{
        call FastAlarm.startAt(t0, dt);
      }
    }else{
      post signalFastAlarm();
      //not used, so just go ahead.
    }
    call SynchCapture.captureRisingEdge();
  }

  async event void FastAlarm.fired(){
    //TX
    if (aNextRequestType == RT_TX){
      aRequestError = call DelayedSend.startSend();
    }else{
      //RX (frame wait)
      //  if we're not mid-reception, resume idle mode.
      //  signal handled with nothing received
    }
    asyncHandled = TRUE;
  }
  

  //even though this is marked async, it's actually only signalled
  //  from task context in HplMsp430Rf1aP.
  async event void Rf1aPhysical.sendDone (int result) { 
    atomic {
      aRequestError = result;
      asyncHandled = TRUE;
    }
    post requestHandled();
  }

  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {}

  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.carrierSense () { }

}
