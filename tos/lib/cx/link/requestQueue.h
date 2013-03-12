#ifndef REQUEST_QUEUE_H
#define REQUEST_QUEUE_H

#include "message.h"
#include "CXLink.h"

#include <stdio.h>

//sleep takes priority, then wakeup, then TX, and finally RX
typedef enum {
  RT_SLEEP = 0,
  RT_WAKEUP = 1,
  RT_TX = 2,
  RT_RX = 3,
} request_type_t;

//frame number increments every 2**-15 * 2**10 = 2**-5 seconds
//32 bit unsigned int: 2**32 * 2**-5 => 2**27 seconds to rollover
//there's between 2**16 and 2**17 seconds in a day (2**16.4)
//This comes out to ~1500 days between rollovers.
typedef struct cx_request{
  uint32_t baseFrame;
  int32_t frameOffset;
  uint32_t requestedTime;
  request_type_t requestType;
  uint32_t duration; //only germane to rx
  bool useTsMicro;
  uint32_t tsMicro;
  message_t* msg;
} cx_request_t;

bool requestLeq(cx_request_t* l, cx_request_t* r,
    uint32_t lastMicroStart, bool microRunning){
  //notes w.r.t rollovers
  // - valid condition near rollover: lastMicroStart, requestedTime
  //   gets misread as lastMicroStart 1.5 days after requestedTime. 
  // - invalid condition near rollover: requestTime, lms 
  //   misread as the timer having been on for 1.5 days prior to
  //   request being made

  //Valid -> invalid: happens if a node is between RX and forward when
  //  the rollover happens. result should be dequeue the TX and throw
  //  it out as having invalid timing info.

  //Invalid -> valid: Shouldn't happen if we're managing the
  //  timer correctly. if it happens, we'd pull it out in the right
  //  order but then decide to throw it out.
  if (l->useTsMicro || r->useTsMicro){
    if (!microRunning){
      //at least one uses micro ref, but timer's not running.
      return l->useTsMicro ? TRUE : FALSE;
    }else if (l->useTsMicro && lastMicroStart > l->requestedTime){
      //l was requested, but the micro timer was started some time
      // later, so l's tsMicro is no longer valid.
      return TRUE;
    }else if (r-> useTsMicro && lastMicroStart > r->requestedTime){
      return FALSE;
    }else{
      //ok, micro times are valid! fall-through.
    }
  }
  {
    int32_t lfn = l->baseFrame + l->frameOffset;
    int32_t rfn = r->baseFrame + r->frameOffset;

    if (lfn < rfn){
      return TRUE;
    }else if (rfn < lfn){
      return FALSE;
    }else{
      return l->requestType <= r->requestType;
    }
  }
}

#endif
