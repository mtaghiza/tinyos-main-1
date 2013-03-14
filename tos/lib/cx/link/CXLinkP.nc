
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
  uses interface Rf1aPacket;
  provides interface Rf1aTransmitFragment;

  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface Timer<T32khz> as FrameTimer;
  uses interface GpioCapture as SynchCapture;

  uses interface Msp430XV2ClockControl;

  uses interface Boot;

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
  message_t* tx_msg;
  uint8_t* tx_pos;
  uint8_t tx_left;
  uint8_t tx_len;
  bool tx_tsSet;
  nx_uint32_t* tx_tsLoc;

  //async-context variables/mirrors
  error_t aRequestError;
  request_type_t aNextRequestType;
  uint32_t aSfdCapture;
  bool asyncHandled = FALSE;
  unsigned int aCount;

  //debug-only
  #define EVENT_LEN 20
  uint8_t events[EVENT_LEN];
  uint8_t eventIndex=0;
  uint8_t trcReady[EVENT_LEN];
  uint8_t trcIndex = 0;

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
        {
          uint8_t i;
          printf("#E");
          for (i = 0; i < EVENT_LEN ; i++){
            printf(" %x", events[i]);
          }
          printf("\r\n");
          printf("#TRC");
          for (i = 0; i < EVENT_LEN ; i++){
            printf(" %u", trcReady[i]);
          }
          printf("\r\n");

        }
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
    if (nextRequest->requestType == RT_TX &&
        nextRequest->typeSpecific.tx.useTsMicro){
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
//        printf("handle %x @ %lu / %lu\r\n", 
//          nextRequest->requestType,         
//          lastFrameNum, 
//          call FrameTimer.gett0() + call FrameTimer.getdt());
        switch (nextRequest -> requestType){
          case RT_FRAMESHIFT:
            lastFrameTime += nextRequest->typeSpecific.frameShift.frameShift;
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
                aNextRequestType = nextRequest->requestType;
                tx_msg = nextRequest->msg;
                tx_pos = (uint8_t*)nextRequest -> msg;
                aSfdCapture = 0;
                tx_len = (call Rf1aPacket.metadata(nextRequest->msg))->payload_length;
                tx_left = tx_len;
                tx_tsLoc = nextRequest->typeSpecific.tx.tsLoc;
                tx_tsSet = FALSE;
                //TODO: TX CX link header setup
                aRequestError = SUCCESS;
                requestError = call Rf1aPhysical.send(tx_pos, tx_len, RF1A_OM_IDLE);

                memset(events, EVENT_LEN, 0);
                eventIndex=0;
                memset(trcReady, EVENT_LEN, 0);
                trcIndex=0;
              }
            }
//            printf("len %u left %u\r\n", tx_len, tx_left);
            if (SUCCESS != requestError){
              handledFrame = lastFrameNum;
              post requestHandled();
            }
            handledFrame = lastFrameNum;
            break;
          case RT_RX:
            if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
              call Msp430XV2ClockControl.startMicroTimer();
              lastMicroStart = lastFrameTime;
            }
            requestError = call Rf1aPhysical.setReceiveBuffer(
              (uint8_t*)nextRequest->msg,
              TOSH_DATA_LENGTH + sizeof(message_header_t),
              TRUE);
            if (SUCCESS == requestError ){
              atomic{
                aNextRequestType = nextRequest->requestType;
                aRequestError = SUCCESS;
                aSfdCapture = 0;
                call FastAlarm.start(nextRequest->typeSpecific.rx.duration);
                call SynchCapture.captureRisingEdge();
              }
            }else{
              post requestHandled();
            }
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
    }else if(r->requestType == RT_TX && r->typeSpecific.tx.useTsMicro && 
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
      r->msg = NULL;
    }
    return r;
  }

  void enqueue(cx_request_t* r){
    if ( r->requestType == RT_TX && r->typeSpecific.tx.useTsMicro){
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
        r->typeSpecific.frameShift.frameShift = frameShift;
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
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_TX);
    if (r != NULL){
      error_t error;
      //TODO: would be nice to use microRef/useMicro for more precise
      //wakeups, i guess.
      if (duration == 0){
        r->typeSpecific.rx.duration = RX_DEFAULT_WAIT;
      } else{
        r->typeSpecific.rx.duration = duration;
      }
      r->msg = msg;
      error = validateRequest(r);
      if (SUCCESS == error){
        enqueue(r);
      }else{
        call Pool.put(r);
      }
      return error;
    } else{
      return ENOMEM;
    }
  }

  default event void CXRequestQueue.receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive_, 
    uint32_t microRef, message_t* msg){}

  command error_t CXRequestQueue.requestSend(uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      nx_uint32_t* tsLoc,
      message_t* msg){
    cx_request_t* r = newRequest(baseFrame, frameOffset, RT_TX);
    if (r != NULL){
      error_t error;
      r->typeSpecific.tx.useTsMicro = useMicro;
      r->typeSpecific.tx.tsMicro = microRef;
      r->typeSpecific.tx.tsLoc = tsLoc;
      r->msg = msg;
      error = validateRequest(r);
      if (SUCCESS == error){
        enqueue(r);
      }else{
        call Pool.put(r);
      }
      return error;
    } else{ 
      return ENOMEM;
    }
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
      }else{
        call Pool.put(r);
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
      } else{
        call Pool.put(r);
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

  task void setTimestamp(){
    atomic{
      events[eventIndex++] = 3;
      tx_tsSet = TRUE;
      *tx_tsLoc = aSfdCapture;
    }
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
    events[eventIndex++]=2;
    if (aNextRequestType == RT_TX){
      if(ENABLE_TIMESTAMPING && tx_tsLoc != NULL){
        post setTimestamp();
      }
    }else if (aNextRequestType == RT_RX){
      //TODO: CHECKME do we have to extend the timeout, or can we just
      //cancel it?
      // should we set a falling edge capture? 
      call FastAlarm.stop();
    }
    call SynchCapture.disable();

    asyncHandled = TRUE;
  }

  task void signalFastAlarm(){
    atomic signal FastAlarm.fired();
  }

  event void DelayedSend.sendReady(){
    if (nextRequest->typeSpecific.tx.useTsMicro){
      int32_t dt = (nextRequest->frameOffset)*FRAMELEN_6_5M;
      uint32_t t0 = nextRequest->typeSpecific.tx.tsMicro;
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
  
  task void signalNoneReceived(){
    didReceive = FALSE;
    post requestHandled();
  }

  task void signalReceived(){
    didReceive = TRUE;
    atomic{
      (call Rf1aPacket.metadata(nextRequest->msg))->payload_length =
      aCount;
    }
    post requestHandled();
  }

  async event void FastAlarm.fired(){
    //TX
    if (aNextRequestType == RT_TX){
      //TODO: FUTURE maybe do a busy-wait here on the timer register
      //and issue the strobe at a more precise instant.
      aRequestError = call DelayedSend.startSend();
    }else if (aNextRequestType == RT_RX){
      //RX (frame wait)
      //  if we're not mid-reception, resume idle mode.
      //  signal handled with nothing received

      aRequestError = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      if (aRequestError == SUCCESS){
        //TODO: FIXME this was required in older version, still needed?
        aRequestError = call Rf1aPhysical.setReceiveBuffer(0, 0, TRUE);
      }
      post signalNoneReceived();
    }
    asyncHandled = TRUE;
  }
  
  
  unsigned int transmitReadyCount(unsigned int count, bool report){
    unsigned int ret;
    if(ENABLE_TIMESTAMPING){
      unsigned int available;
      //pause at the start of the timestamp field if it's required but we haven't figured it out
      //yet.
      if (tx_tsSet || tx_tsLoc == NULL){
        available = tx_left;
      }else{
        available = (uint8_t*)tx_tsLoc - tx_pos;
      }
      ret = (available > count)? count : available;
    }else {
      ret = tx_left > count? count: tx_left;
    } 
    if (report){
      trcReady[trcIndex++] = ret;
    }
    return ret;
  }

  async command unsigned int Rf1aTransmitFragment.transmitReadyCount(unsigned int count){
    return transmitReadyCount(count, TRUE);
  }

  async command const uint8_t* Rf1aTransmitFragment.transmitData(unsigned int count){
    unsigned int available = transmitReadyCount(count, FALSE);
    const uint8_t* ret= tx_pos;
    events[eventIndex++] = 1;
    tx_left -= available;
    tx_pos += available;
    return ret;
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
  

  //again, marked async but signaled from task sometimes
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    atomic{
      call FastAlarm.stop();
      aRequestError = result;
      aCount = count;
      post signalReceived();
    }
  }

  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.carrierSense () { }

  event void Boot.booted(){
    call Msp430XV2ClockControl.stopMicroTimer();
  }

}
