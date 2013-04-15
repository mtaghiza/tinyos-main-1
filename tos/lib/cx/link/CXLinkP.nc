
 #include "CXLink.h"
 #include "CXLinkDebug.h"
module CXLinkP { provides interface SplitControl;
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
  uint32_t fastAlarmAtFrameTimerFired;

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

  //frame-resynch
  uint32_t a32kCapture;
  
  //indicate to requestHandled whether RX with good CRC or TX.
  bool shouldSynch;


  //forward declarations
  task void readyNextRequest();
  error_t validateRequest(cx_request_t* r);
  cx_request_t* newRequest(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, request_type_t requestType, void* md);
  
  void updateLastFrameNum(){
    //this should be safe from integer wrap
    uint32_t now = call FrameTimer.getNow();
    uint32_t elapsedTime = now - lastFrameTime;
    uint32_t elapsedFrames = elapsedTime/FRAMELEN_32K;
    lastFrameTime += (elapsedFrames*FRAMELEN_32K);
    lastFrameNum += elapsedFrames;
  }

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    updateLastFrameNum();
    return lastFrameNum + 1;
  }

  uint32_t fastToSlow(uint32_t fastTicks){
    //OK w.r.t overflow as long as fastTicks is 22 bits or less (0.64 seconds)
    return (FRAMELEN_32K*fastTicks)/FRAMELEN_6_5M;
  }

  task void requestHandled(){
    //if the request finished in the async context, need to copy
    //results back to the task context
    uint32_t microRef;
    uint32_t t32kRef = 0;
    uint32_t reqFrame = nextRequest->baseFrame + nextRequest->frameOffset;
    atomic{
      if (asyncHandled){
        microRef = aSfdCapture;
        requestError = aRequestError;
      }

      if (microRef != 0 && shouldSynch){
        uint32_t fastRef1 = call FastAlarm.getNow();
        uint32_t slowRef = call FrameTimer.getNow();
        uint32_t fastRef2 = call FastAlarm.getNow();
        uint32_t fastTicks;
        uint32_t slowTicks;
        microRef -= (aNextRequestType == RT_TX)? TX_STROBE_CORRECTION : RX_STROBE_CORRECTION;
        //elapsed fast-ticks since strobe
        fastTicks = ((fastRef1+fastRef2)/2) - microRef;
        //elapsed slow-ticks since strobe
        slowTicks = fastToSlow(fastTicks);
//        printf_LINK("lms %lu cap %lu ref %lu fr1 %lu fr2 %lu sr %lu ft %lu st %lu ",
//          lastMicroStart,
//          aSfdCapture, microRef,
//          fastRef1, fastRef2, slowRef,
//          fastTicks, slowTicks);
//        printf_LINK("%lu -> ", lastFrameTime);
        t32kRef = slowRef - slowTicks;
        //push frame time back to allow for rx/tx preparation
        lastFrameTime = slowRef-slowTicks - PREP_TIME_32KHZ;
//        printf_LINK("%lu \r\n", lastFrameTime);
      }
      if (microRef !=0 && !shouldSynch){
        printf_LINK("Failed CRC don't resynch\r\n");
      }
      asyncHandled = FALSE;
    }
    switch(nextRequest -> requestType){
      case RT_FRAMESHIFT:
        signal CXRequestQueue.frameShiftHandled(requestError,
          nextRequest -> layerCount - 1,
          handledFrame, reqFrame);
        break;
      case RT_SLEEP:
        signal CXRequestQueue.sleepHandled(requestError, 
          nextRequest -> layerCount - 1,
          handledFrame, reqFrame);
        break;
      case RT_WAKEUP:
        signal CXRequestQueue.wakeupHandled(requestError,
          nextRequest -> layerCount - 1,
          handledFrame, reqFrame); 
        break;
      case RT_TX:
        signal CXRequestQueue.sendHandled(requestError, 
          nextRequest -> layerCount - 1,
          handledFrame,
          reqFrame,
          microRef, t32kRef,
          nextRequest-> next,
          nextRequest->msg);
        break;
      case RT_RX:
        signal CXRequestQueue.receiveHandled(requestError,
          nextRequest -> layerCount - 1,
          handledFrame, 
          reqFrame,
          didReceive && call Rf1aPhysicalMetadata.crcPassed(call Rf1aPacket.metadata(nextRequest->msg)), 
          microRef, t32kRef, nextRequest->next, nextRequest->msg);
        break;

      case RT_MARK:
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
      post readyNextRequest();
    }else{
      nextRequest = NULL;
    }
    
    if (LINK_DEBUG_FRAME_BOUNDARIES){
      //nothing scheduled or next scheduled event is some frame other
      //than the upcoming one.
      if (nextRequest == NULL ||
          nextRequest -> baseFrame + nextRequest->frameOffset 
          != lastFrameNum+1){

        //re-enqueue nextRequest
        if (nextRequest != NULL){
          call Queue.enqueue(nextRequest);
        }else{
          //rnr will already be posted if nextRequest != NULL.
          post readyNextRequest();
        }
        //we'll do an RT_MARK instead
        nextRequest = newRequest(0, lastFrameNum, 1, RT_MARK, NULL);
      }
    }
  }

  event void FrameTimer.fired(){
    updateLastFrameNum();
    if (nextRequest != NULL){
      uint32_t targetFrame = nextRequest->baseFrame + nextRequest -> frameOffset; 
      handledFrame = lastFrameNum;
      if (targetFrame == lastFrameNum){
        if (LINK_DEBUG_FRAME_BOUNDARIES){
          //TODO: DEBUG remove 
          atomic P1OUT ^= BIT1;
        }
//        if (nextRequest -> requestType != RT_MARK){
//          printf_LINK("handle %x @ %lu / %lu\r\n", 
//            nextRequest->requestType,         
//            lastFrameNum, 
//            call FrameTimer.gett0() + call FrameTimer.getdt());
//        }
        switch (nextRequest -> requestType){
          case RT_FRAMESHIFT:
            lastFrameTime += nextRequest->typeSpecific.frameShift.frameShift;
            requestError = SUCCESS;
            post requestHandled();
            break;
          case RT_SLEEP:
            //if radio is active, shut it off.
            requestError = call Rf1aPhysical.sleep();
            //TODO: FUTURE frequency-scaling: turn it down
            post requestHandled();
            break;
          case RT_WAKEUP:
            requestError = call Rf1aPhysical.resumeIdleMode(FALSE);
            //TODO: FUTURE frequency-scaling: turn it up.
            //if radio is off, turn it on (idle)
            post requestHandled();
            break;
          case RT_TX:
            shouldSynch = TRUE;
            if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
              call Msp430XV2ClockControl.startMicroTimer();
              lastMicroStart = lastFrameTime;
            }
            fastAlarmAtFrameTimerFired = call FastAlarm.getNow();
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
                aRequestError = SUCCESS;
                requestError = call Rf1aPhysical.send(tx_pos, tx_len, RF1A_OM_IDLE);

              }
            }
            if (SUCCESS != requestError){
              post requestHandled();
            }
            break;

          case RT_RX:
            shouldSynch = FALSE;
            if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
              call Msp430XV2ClockControl.startMicroTimer();
              lastMicroStart = lastFrameTime;
            }
            didReceive = FALSE;
            //TODO FUTURE: the longer we can put off entering RX mode,
            //the more energy we can save. with slack ratio=6, it
            //looks like we typically spend 0.38 ms in RX before the
            //transmission begins.
            //another way to be hardcore about this would be to set
            //one fastalarm for just after tx start is expected and
            //check for channel activity. If there is nothing, stop
            //immediately rather than waiting for SFD timeout.
            requestError = call Rf1aPhysical.setReceiveBuffer(
              (uint8_t*)nextRequest->msg,
              TOSH_DATA_LENGTH + sizeof(message_header_t),
              TRUE);
            if (SUCCESS == requestError ){
              atomic{P1OUT |= BIT2;}
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

          case RT_MARK:
            //TODO: DEBUG remove
            post requestHandled();
            break;

          default:
            //should not happen.
        }
      }else if (targetFrame < lastFrameNum){
        printf_LINK("Missed\r\n");
        //we have missed the intended frame. signal handled
        requestError = FAIL;
        post requestHandled();
      }else if (targetFrame > lastFrameNum){
        printf_LINK("Early\r\n");
        //shouldn't happen. re-doing readyNextRequest should work it
        //out. 
        call Queue.enqueue(nextRequest);
        nextRequest = call Queue.dequeue();
        post readyNextRequest();
      }
    }else{
      printf_LINK("nextRequest NULL\r\n");
    }
  }

  task void readyNextRequest(){
    if (nextRequest != NULL){
      //if request is not valid, we need to signal its handling
      //  and pull the next one from the queue.
      error_t err = validateRequest(nextRequest);
      if (SUCCESS != err){
        requestError = err;
        updateLastFrameNum();
        handledFrame = lastFrameNum;
        if (nextRequest->requestType != RT_MARK){
          printf("rnR: %x %x@ %lu\r\n", requestError,
            nextRequest->requestType, 
            nextRequest->baseFrame + nextRequest->frameOffset);
        }
        post requestHandled();
      }else{
        uint32_t targetFrame = nextRequest -> baseFrame + nextRequest->frameOffset;
        uint32_t dt = (targetFrame - lastFrameNum)*FRAMELEN_32K;
  
        call FrameTimer.startOneShotAt(lastFrameTime, dt);
        if (nextRequest->requestType != RT_MARK){
          printf_LINK("N: %x @%lu (%lu)\r\n", 
            nextRequest->requestType,
            targetFrame,
            lastFrameTime+dt);
        }
      }
    }
  }

  error_t validateRequest(cx_request_t* r){
    //event in the past? I guess we were busy.
    if (r->baseFrame + r->frameOffset < call CXRequestQueue.nextFrame(FALSE)){
      return EBUSY;

    //micro timer required but it's either off or has been stopped
    //since the request was made
    }else if(r->requestType == RT_TX && r->typeSpecific.tx.useTsMicro && 
      (( ! call Msp430XV2ClockControl.isMicroTimerRunning()) 
         || (lastMicroStart > r->requestedTime))){
      return EINVAL;
    }else if (r->baseFrame == INVALID_FRAME || r->baseFrame + r->frameOffset == INVALID_FRAME){
      return EINVAL;
    }
    return SUCCESS;
  }
  
  cx_request_t* newRequest(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, request_type_t requestType, void* md){
    cx_request_t* r = call Pool.get();
    if (r != NULL){
      r->layerCount = layerCount;
      r->requestedTime = call FrameTimer.getNow();
      r->baseFrame = baseFrame;
      r->requestType = requestType;
      r->frameOffset = frameOffset;
      r->next = md;
      r->msg = NULL;
    }else{
      printf("!RP empty!\r\n");
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

  command error_t CXRequestQueue.requestFrameShift(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, int32_t frameShift){
    cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset,
      RT_FRAMESHIFT, NULL);
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

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration,
      void* md, message_t* msg){
    if (msg == NULL){
      printf("link.cxrq.rr null\r\n");
      return EINVAL;
    } else{
      cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset, RT_RX, md);
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
        printf("Link.NOMEM\r\n");
        return ENOMEM;
      }
    }
  }

  default event void CXRequestQueue.receiveHandled(error_t error, 
    uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame, bool didReceive_, 
    uint32_t microRef, uint32_t t32kRef, void* md, message_t* msg){}

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      nx_uint32_t* tsLoc,
      void* md, message_t* msg){
    cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset, RT_TX, md);
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
    uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame, uint32_t microRef, 
    uint32_t t32kRef, void* md, message_t* msg){}

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset, RT_SLEEP,
      NULL);
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

  default event void CXRequestQueue.sleepHandled(error_t error,
  uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame){ }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset){
    cx_request_t* r = newRequest(layerCount + 1, baseFrame, frameOffset, RT_WAKEUP,
      NULL);
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

  default event void CXRequestQueue.wakeupHandled(error_t error,
  uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame){}

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
    nx_uint32_t tsVal;
    atomic{
      //best fast/slow ref we can get
      uint32_t fastRef1 = call FastAlarm.getNow();
      uint32_t slowRef = call FrameTimer.getNow();
      uint32_t fastRef2 = call FastAlarm.getNow();
      //elapsed fast-ticks since capture
      uint32_t fastTicks = ((fastRef1+fastRef2)/2) - aSfdCapture;
      //convert to slow ticks
      uint32_t slowTicks = fastToSlow(fastTicks);
      tsVal = slowRef - slowTicks;

      //set approximate timestamp 
      *tx_tsLoc = tsVal;
      tx_tsSet = TRUE;
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


  event void DelayedSend.sendReady(){
    int32_t dt;
    uint32_t t0;
    uint32_t now = call FastAlarm.getNow();
    if (nextRequest->typeSpecific.tx.useTsMicro){
      //TODO: FIXME Wrapping logic/signedness issues? could mandate that
      //  frameOffset is always non-negative, that could simplify
      //  matters.
      dt = (nextRequest->frameOffset)*FRAMELEN_6_5M;
      t0 = nextRequest->typeSpecific.tx.tsMicro;
    } else{
      t0 = fastAlarmAtFrameTimerFired;
      dt = PREP_TIME_FAST;
    }

    if ( t0 + dt < now + MIN_STROBE_CLEARANCE ){
      printf("%lu + %lu = %lu < %lu + %lu = %lu\r\n",
        t0, dt, t0+dt, now, MIN_STROBE_CLEARANCE,
        now+MIN_STROBE_CLEARANCE);
      //not enough time, so fail.
      requestError = FAIL;
      //cancel the transmission.
      call Rf1aPhysical.resumeIdleMode(FALSE);
      post requestHandled();
    }else{
//      setAt = call FastAlarm.getNow();
//      post reportMicro();
      call FastAlarm.startAt(t0, dt);
      call SynchCapture.captureRisingEdge();
    }
  }
  
  task void signalNoneReceived(){
    didReceive = FALSE;
    post requestHandled();
  }

  task void signalReceived(){
    didReceive = TRUE;
    //store the phy metadata (including CRC)
    call Rf1aPhysicalMetadata.store(call Rf1aPacket.metadata(nextRequest->msg));
    atomic{
      (call Rf1aPacket.metadata(nextRequest->msg))->payload_length =
      aCount;
    }
    shouldSynch = call Rf1aPacket.crcPassed(nextRequest->msg);
    printf_LINK("RX crc %x\r\n", 
      call Rf1aPacket.crcPassed(nextRequest->msg));
    post requestHandled();
  }

  norace uint32_t txAlarm;

  task void reportTx(){
    printf_LINK("tx@ %lu\r\n", txAlarm);
  }

  async event void FastAlarm.fired(){
    //TX
    if (aNextRequestType == RT_TX){
      //TODO: FUTURE maybe do a busy-wait here on the timer register
      //and issue the strobe at a more precise instant.
      atomic{P1OUT |= BIT2;}
      aRequestError = call DelayedSend.startSend();
      txAlarm = call FastAlarm.getAlarm();
      post reportTx();

      if (aRequestError != SUCCESS){
        post requestHandled();
      }
    }else if (aNextRequestType == RT_RX){
      //RX (frame wait)
      //  if we're not mid-reception, resume idle mode.
      //  signal handled with nothing received
      atomic{
        P1OUT^=BIT4;
        P1OUT ^= BIT4;
        P1OUT &= ~BIT2;
      }
      aRequestError = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      if (aRequestError == SUCCESS){
        //TODO: FIXME this was required in older version, still needed?
        aRequestError = call Rf1aPhysical.setReceiveBuffer(0, 0, TRUE);
      }
      post signalNoneReceived();
    }
    asyncHandled = TRUE;
  }
  

  async command unsigned int Rf1aTransmitFragment.transmitReadyCount(unsigned int count){
    if(ENABLE_TIMESTAMPING){
      unsigned int available;
      //pause at the start of the timestamp field if it's required but we haven't figured it out
      //yet.
      //This is marked async, but called from task context by FEC
      //  component.
      atomic{
        if (tx_tsSet || tx_tsLoc == NULL){
          available = tx_left;
        }else{
          available = (uint8_t*)tx_tsLoc - tx_pos;
        }
      }
      return (available > count)? count : available;
    }else {
      return tx_left > count? count: tx_left;
    } 
  }

  async command const uint8_t* Rf1aTransmitFragment.transmitData(unsigned int count){
    unsigned int available = call Rf1aTransmitFragment.transmitReadyCount(count);
    //called from task context by FEC component
    atomic{
      const uint8_t* ret= tx_pos;
      tx_left -= available;
      tx_pos += available;
      return ret;
    }
  }

  //even though this is marked async, it's actually only signalled
  //  from task context in HplMsp430Rf1aP.
  async event void Rf1aPhysical.sendDone (int result) { 
    atomic{P1OUT &= ~BIT2;}
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
    atomic{P1OUT &= ~BIT2;}
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
