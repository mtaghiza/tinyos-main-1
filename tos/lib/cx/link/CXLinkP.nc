/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


 #include "CXLink.h"
 #include "CXLinkDebug.h"
 #include "CXSchedulerDebug.h"
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
  uses interface Packet;
  uses interface CXPacketMetadata;
  provides interface Rf1aTransmitFragment;

  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface Timer<T32khz> as FrameTimer;
  uses interface GpioCapture as SynchCapture;

  uses interface Msp430XV2ClockControl;

  uses interface Boot;

  uses interface StateDump;

} implementation {

  bool active = FALSE;
  bool aDidSense = FALSE;
  bool aExtended = FALSE;

  uint32_t lastFrameNum = 0;
  uint32_t lastFrameTime = 0;
  uint32_t fastAlarmAtFrameTimerFired;


  //keep count of how many outstanding requests rely on the
  //alarm so that we can duty cycle it when it's not in use.
  uint8_t alarmUsers = 0;
  
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

  
  //indicate to requestHandled whether RX with good CRC or TX.
  bool shouldSynch;

  //debug
  request_type_t lastType;

  //forward declarations
  task void readyNextRequest();
  error_t validateRequest(cx_request_t* r);
  cx_request_t* newRequest(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, request_type_t requestType, void* md);
 
  #ifndef UFN_ADJUST_LEN 
  #define UFN_ADJUST_LEN 8
  #endif
  typedef struct ufn_adjust{
    uint32_t now;
    uint32_t lft;
    uint32_t lfn;
    uint32_t et;
    uint32_t ef;
    uint32_t ft;
    uint32_t fn;
    uint8_t from;
  } ufn_adjust_t;

  ufn_adjust_t ufnArr[UFN_ADJUST_LEN];
  uint8_t ufnIndex = 0;
  
  #ifndef QUEUE_HISTORY_LEN
  #define QUEUE_HISTORY_LEN 16
  #endif
  typedef struct queue_history{
    request_type_t requestType;
    error_t validation;
    uint32_t reqFrame;
    error_t handleErr;
  } queue_history_t;

  queue_history_t queueHistory[QUEUE_HISTORY_LEN];
  uint8_t qhi = QUEUE_HISTORY_LEN-1;
  
  void updateLastFrameNum(uint8_t from){
    //this should be safe from integer wrap
    uint32_t now = call FrameTimer.getNow();
    uint32_t elapsedTime = now - lastFrameTime;
    uint32_t elapsedFrames = elapsedTime/FRAMELEN_32K;
    ufnArr[ufnIndex].now = now;
    ufnArr[ufnIndex].lft = lastFrameTime;
    ufnArr[ufnIndex].lfn = lastFrameNum;
    ufnArr[ufnIndex].et = elapsedTime;
    ufnArr[ufnIndex].ef = elapsedFrames;

    lastFrameTime += (elapsedFrames*FRAMELEN_32K);
    lastFrameNum += elapsedFrames;

    ufnArr[ufnIndex].ft = lastFrameTime;
    ufnArr[ufnIndex].fn = lastFrameNum;
    ufnArr[ufnIndex].from = from;
    //overwrite entries which don't change the frame number.
    if (elapsedFrames){
      ufnIndex = (ufnIndex+1)%UFN_ADJUST_LEN;
    }
  }

  task void logFrameAdjustments(){
    uint8_t i = ufnIndex + 1;
    uint8_t k;
    cwarn(LINK, "ULFN\r\n");
    for (k = 0; k < UFN_ADJUST_LEN; k++){
      ufn_adjust_t* a = &ufnArr[(i+k)%UFN_ADJUST_LEN];
      cwarnclr(LINK, " %u %u @ %lu (%lu, %lu) + (%lu, %lu) = (%lu, %lu)\r\n", 
        k, a->from,
        a->now, 
        a-> lft, a->lfn,
        a-> et,  a-> ef,
        a-> ft,  a-> fn);
    }
  }

  task void logQueueHistory(){
    uint8_t i = qhi +1;
    uint8_t k;
    cwarn(LINK, "QH\r\n");
    for (k = 0; k < QUEUE_HISTORY_LEN; k++){
      queue_history_t* qh = &queueHistory[(i+k)%QUEUE_HISTORY_LEN];
      cwarnclr(LINK, " %x @ %lu : %x %x\r\n",
        qh->requestType,
        qh->reqFrame,
        qh->validation,
        qh->handleErr);
    }
  }

  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    updateLastFrameNum(0);
    return lastFrameNum + 1;
  }

  uint32_t fastToSlow(uint32_t fastTicks){
    //OK w.r.t overflow as long as fastTicks is 22 bits or less (0.64 seconds)
    return (FRAMELEN_32K*fastTicks)/FRAMELEN_6_5M;
  }

  task void senseNoRX(){
    cinfo(LINK, "SNRX\r\n");
  }

  task void requestHandled(){
    //if the request finished in the async context, need to copy
    //results back to the task context
    uint32_t microRef;
    uint32_t t32kRef = 0;
    uint32_t reqFrame = nextRequest->baseFrame + nextRequest->frameOffset;
    bool crcf = FALSE;

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
        //this should be wrap-safe.
        fastTicks = fastRef1 + ((fastRef2-fastRef1)/2) - microRef;
        //elapsed slow-ticks since strobe
        slowTicks = fastToSlow(fastTicks);
        t32kRef = slowRef - slowTicks;
        //push frame time back to allow for rx/tx preparation
        lastFrameTime = slowRef-slowTicks - PREP_TIME_32KHZ;
        if (lastFrameTime > slowRef){
          cerror(LINK, "RESYNCH %lu > %lu : %lu %lu %lu %lu %lu %lu\r\n",
            lastFrameTime, slowRef,
            fastRef1, fastRef2, microRef,
            fastTicks, slowTicks,
            t32kRef);
          call StateDump.requestDump();
        }
      }
      if (microRef !=0 && !shouldSynch){
        crcf = TRUE;
      }
      asyncHandled = FALSE;
    }
    if (crcf){
      cinfo(LINK, "CRCF %lu\r\n",
        reqFrame);
    }
    lastType = nextRequest->requestType;
    queueHistory[qhi].handleErr = requestError;
    switch(nextRequest -> requestType){
      case RT_SLEEP:
        if (requestError == SUCCESS){
          active = FALSE;
        }
        signal CXRequestQueue.sleepHandled(requestError, 
          nextRequest -> layerCount - 1,
          handledFrame, reqFrame);
        break;
      case RT_WAKEUP:
        if (requestError == SUCCESS){
          active = TRUE;
        }
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
        {
          if (didReceive && t32kRef !=0){
            //N.B. I'm vaguely concerned about rounding problems here.
            //I see some originFrame calculations in the traces that
            //come up 1 short (before this fix, when we were just
            //using lastFrameNum at the time that receiveHandled was
            //run). It's unclear to me how this could ever happen in
            //either case, but there you have it.
            handledFrame = lastFrameNum + (t32kRef - lastFrameTime)/FRAMELEN_32K;
          }
          if (requestError != SUCCESS && requestError != ERETRY){
            cwarn(LINK, "RXE %x\r\n", requestError);
          }
          atomic{
            if (!didReceive && aDidSense){
              lastFrameTime -= SNRX_SCOOT;
              post senseNoRX();
            }
            aDidSense = FALSE;
          }
          signal CXRequestQueue.receiveHandled(requestError,
            nextRequest -> layerCount - 1,
            handledFrame, 
            reqFrame,
            didReceive && (call Rf1aPhysicalMetadata.crcPassed(call
            Rf1aPacket.metadata(nextRequest->msg)) || !ENABLE_CRC_CHECK ), 
            microRef, t32kRef, nextRequest->next, nextRequest->msg);
          break;
        }
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
      #if ENABLE_XT2_DC == 1
      call Msp430XV2ClockControl.stopMicroTimer();
      #else
      #warning XT2 duty-cycling off!
      #endif
    }

    call Pool.put(nextRequest);
    if (! call Queue.empty()){
      nextRequest = call Queue.dequeue();
      post readyNextRequest();
    }else{
      nextRequest = NULL;
    }
    
    if (LINK_DEBUG_FRAME_BOUNDARIES && MARK_ALL_FRAMES){
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
    updateLastFrameNum(1);
    if (nextRequest != NULL){
      uint32_t targetFrame = nextRequest->baseFrame + nextRequest -> frameOffset; 
      handledFrame = lastFrameNum;
      if (targetFrame == lastFrameNum){
        if (LINK_DEBUG_FRAME_BOUNDARIES){
          //TODO: DEBUG remove 
          atomic P1OUT ^= BIT1;
        }
        switch (nextRequest -> requestType){
          case RT_SLEEP:
            if (LINK_DEBUG_WAKEUP){
              atomic P1OUT &= ~BIT3;
            }
            //if radio is active, shut it off.
            requestError = call Rf1aPhysical.sleep();
            //TODO: FUTURE frequency-scaling: turn it down
            post requestHandled();
            break;
          case RT_WAKEUP:
            if (LINK_DEBUG_WAKEUP){
              atomic P1OUT |= BIT3;
            }
            requestError = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            if (requestError == SUCCESS){
              //TODO: where should channel # come from?
              requestError = call Rf1aPhysical.setChannel(0);
            }
            //TODO: FUTURE frequency-scaling: turn it up.
            //if radio is off, turn it on (idle)
            post requestHandled();
            break;
          case RT_TX:
            if (active){
              shouldSynch = TRUE;
              if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
                call Msp430XV2ClockControl.startMicroTimer();
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
                  tx_tsLoc = call CXPacketMetadata.getTSLoc(nextRequest->msg);
                  tx_tsSet = FALSE;
                  aRequestError = SUCCESS;
                  requestError = call Rf1aPhysical.send(tx_pos, tx_len, RF1A_OM_IDLE);
                  //if requestError is not success at this point, radio
                  //is in FSTXON. put it back to idle.
                  if (SUCCESS != requestError){
                    call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
                  }
                }
              }
              if (SUCCESS != requestError){
                post requestHandled();
              }
            } else {
              //radio is in sleep? fail the tx.
              requestError = EOFF;
              post requestHandled();
            }
            break;

          case RT_RX:

            if (active){
              shouldSynch = FALSE;
              if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
                call Msp430XV2ClockControl.startMicroTimer();
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
                  aDidSense = FALSE;
                  aNextRequestType = nextRequest->requestType;
                  aRequestError = SUCCESS;
                  aSfdCapture = 0;
                  aExtended = FALSE;
                  call FastAlarm.start(nextRequest->typeSpecific.rx.duration + PREP_TIME_FAST);
                  call SynchCapture.captureRisingEdge();
                }
              }else{
                post requestHandled();
              }
            } else {
              //rx request while sleeping: success/no reception
              didReceive = FALSE;
              requestError = SUCCESS;
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
        cwarn(LINK, "Missed %lu < %lu\r\n", 
          targetFrame, lastFrameNum);
        //we have missed the intended frame. signal handled
        requestError = EBUSY;
        post requestHandled();
      }else if (targetFrame > lastFrameNum){
        cwarn(LINK, "Early\r\n");
        //shouldn't happen. re-doing readyNextRequest should work it
        //out. 
        call Queue.enqueue(nextRequest);
        nextRequest = call Queue.dequeue();
        post readyNextRequest();
      }
    }else{
      cerror(LINK, "nextRequest NULL\r\n");
    }
  }
  
  

  task void readyNextRequest(){
    if (nextRequest != NULL){
      //if request is not valid, we need to signal its handling
      //  and pull the next one from the queue.
      error_t err = validateRequest(nextRequest);
      if (nextRequest->requestType == RT_RX){
        cdbg(LINKQUEUE, "pop RX %p\r\n", nextRequest->msg);
      } else if (nextRequest ->requestType == RT_TX){
        cdbg(LINKQUEUE, "pop TX %p\r\n", nextRequest->msg);
      }
      qhi = (qhi+1)%QUEUE_HISTORY_LEN;
      queueHistory[qhi].requestType = nextRequest->requestType;
      queueHistory[qhi].validation = err;
      queueHistory[qhi].reqFrame = (nextRequest->baseFrame + nextRequest->frameOffset);
      queueHistory[qhi].handleErr = ELAST;

      if (SUCCESS != err){
        requestError = err;
        updateLastFrameNum(2);
        handledFrame = lastFrameNum;
        if (nextRequest->requestType != RT_MARK){
          cdbg(LINKQUEUE, "rnR: %x %x@ %lu\r\n", requestError,
            nextRequest->requestType, 
            nextRequest->baseFrame + nextRequest->frameOffset);
        }
        post requestHandled();
      }else{
        //Adjust lastFrameTime to be consistent with the skew
        //correction etc, if needed.
        /**
        lft = (lfn - rfn)*FRAMELEN_32K + rft + correction - prep
        **/

        if (nextRequest->requestType == RT_WAKEUP 
            && nextRequest->typeSpecific.wakeup.refTime != INVALID_TIMESTAMP 
            && nextRequest->typeSpecific.wakeup.refFrame != INVALID_FRAME 
            && nextRequest->typeSpecific.wakeup.refFrame < lastFrameNum){
          uint32_t rfn = nextRequest->typeSpecific.wakeup.refFrame;
          uint32_t rft = nextRequest->typeSpecific.wakeup.refTime;
          int32_t c = nextRequest->typeSpecific.wakeup.correction;
          uint32_t newLft = (lastFrameNum-rfn)*FRAMELEN_32K
            + rft + c - PREP_TIME_32KHZ;
          cinfo(SKEW_APPLY, "WU %lu -> %lu %lu %lu %lu %lu\r\n",
            lastFrameTime, newLft,
            rft, rfn, lastFrameNum, nextRequest->baseFrame + nextRequest->frameOffset);
          if ((lastFrameTime > newLft && (lastFrameTime - newLft) > FRAMELEN_32K ) 
              || (lastFrameTime < newLft && (newLft - lastFrameTime) > FRAMELEN_32K )){
            cwarn(SKEW_APPLY, "LWU\r\n");
          }else{
            lastFrameTime = newLft;
          }
        }else if (nextRequest->requestType == RT_WAKEUP){
          cwarn(SKEW_APPLY, "BWU %lu %lu %lu %lu\r\n",
            lastFrameNum, 
            lastFrameTime,
            nextRequest->typeSpecific.wakeup.refFrame,
            nextRequest->typeSpecific.wakeup.refTime);
        }
        {
          uint32_t targetFrame = nextRequest -> baseFrame + nextRequest->frameOffset;
          uint32_t t0 = lastFrameTime;
          uint32_t dt = (targetFrame - lastFrameNum)*FRAMELEN_32K;
  
          call FrameTimer.startOneShotAt(t0, dt);
          if (nextRequest->requestType != RT_MARK){
            uint32_t now = call FrameTimer.getNow();
            cinfo(LINKQUEUE, "N: %x @%lu", 
              nextRequest->requestType,
              targetFrame);
            cdbg(LINKQUEUE, " (%lu %lu %lu)", 
              t0, dt, now);
            cinfo(LINKQUEUE, "\r\n");
            if (nextRequest->requestType == RT_RX){
              cinfo(LINKQUEUE, "LR %lu\r\n",
                nextRequest->typeSpecific.rx.duration);
            }
          }
        }
      }
    }
  }

  error_t validateRequest(cx_request_t* r){
    //event in the past? I guess we were busy.
    if (r->baseFrame + r->frameOffset < call CXRequestQueue.nextFrame(FALSE)){
      //ERETRY: specifically means that a TX or RX was preempted.
      if ((r->requestType == RT_TX || r->requestType == RT_RX) 
            && r->baseFrame + r->frameOffset == handledFrame){
        cdbg(LINK, "LR %lu + %lu %lu %lu %lu (%x)\r\n",
          r->baseFrame, r->frameOffset, 
          lastFrameNum, handledFrame,
          call CXRequestQueue.nextFrame(FALSE),
          lastType);
        return ERETRY;
      }else{ 
        cdbg(LINK, "LB %lu + %lu %lu %lu %lu (%x)\r\n",
          r->baseFrame, r->frameOffset, 
          lastFrameNum, handledFrame, 
          call CXRequestQueue.nextFrame(FALSE),
          lastType);
        return EBUSY;
      }

    //micro timer required but it's either off or has been stopped
    //since the request was made
    }else if(r->requestType == RT_TX && r->typeSpecific.tx.useTsMicro && 
      ( ! call Msp430XV2ClockControl.isMicroTimerRunning())){
      cerror(LINK, "micro required\r\n");
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
      cerror(LINK, "RP empty!\r\n");
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

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration,
      void* md, message_t* msg){
    if (msg == NULL){
      cerror(LINK, "link.cxrq.rr null\r\n");
      return EINVAL;
    } else{
      cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset, RT_RX, md);
      call Packet.clear(msg);
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
          cdbg(LINKQUEUE, "push RX %p\r\n", msg);
        }else{
          call Pool.put(r);
        }
        return error;
      } else{
        cerror(LINK, "l.rr.nomem\r\n");
        return ENOMEM;
      }
    }
  }

  default event void CXRequestQueue.receiveHandled(error_t error, 
    uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame, bool didReceive_, 
    uint32_t microRef, uint32_t t32kRef, void* md, message_t* msg){}

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef,
      void* md, message_t* msg){
    cx_request_t* r = newRequest(layerCount+1, baseFrame, frameOffset, RT_TX, md);
    if (r != NULL){
      error_t error;
      r->typeSpecific.tx.useTsMicro = useMicro;
      r->typeSpecific.tx.tsMicro = microRef;
      r->typeSpecific.tx.txPriority = txPriority;
      r->msg = msg;
      error = validateRequest(r);
      if (SUCCESS == error){
        enqueue(r);
        cdbg(LINKQUEUE, "push TX %p\r\n", msg);
      }else{
        call Pool.put(r);
      }
      return error;
    } else{
      cerror(LINK, "l.rs.nomem\r\n");
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
      cerror(LINK, "l.rsl.nomem\r\n");
      return ENOMEM;
    }
  }

  default event void CXRequestQueue.sleepHandled(error_t error,
  uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame){ }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, uint32_t baseFrame, 
      int32_t frameOffset, uint32_t refFrame, uint32_t refTime, int32_t correction){
    cx_request_t* r = newRequest(layerCount + 1, baseFrame, frameOffset, RT_WAKEUP,
      NULL);
    if (r != NULL){
      error_t error = validateRequest(r);
      if (SUCCESS == error){
        r->typeSpecific.wakeup.refFrame = refFrame;
        r->typeSpecific.wakeup.refTime = refTime;
        r->typeSpecific.wakeup.correction = correction;
        enqueue(r);
      } else{
        call Pool.put(r);
      }
      return error;
    } else{ 
      cerror(LINK, "l.rw.nomem\r\n");
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
      cerror(LINK, "%lu + %lu = %lu < %lu + %lu = %lu\r\n",
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
    cdbg(LINK, "RX crc %x\r\n", 
      call Rf1aPacket.crcPassed(nextRequest->msg));
    post requestHandled();
  }

  norace uint32_t txAlarm;

  task void reportTx(){
    cdbg(LINK, "tx@ %lu\r\n", txAlarm);
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
      // ignore the timeout if we have already captured the start of
      // the packet, but didn't kill the timeout fast enough.
      if (! aSfdCapture){
        //extend the timeout if we have detected channel activity.
        if (aDidSense && ! aExtended){
          aExtended = TRUE;
          call FastAlarm.start(RX_EXTEND);
        } else {
          //timed out, no conditions met to extend or ignore this:
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
      }
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
  async event void Rf1aPhysical.carrierSense () { 
    aDidSense = TRUE;
  }

  event void Boot.booted(){
    call Msp430XV2ClockControl.stopMicroTimer();
  }

  event void StateDump.dumpRequested(){
    post logFrameAdjustments();
    post logQueueHistory();
  }

}
