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

typedef struct cx_request{
  uint32_t tsBase32k;
  int32_t frameOffset;
  uint32_t requestedTime;
  request_type_t requestType;
  uint32_t duration; //only germane to rx
  bool useTsMicro;
  uint32_t tsMicro;
  message_t* msg;
} cx_request_t;

bool requestLeq(cx_request_t* l, cx_request_t* r,
    uint32_t lastMicroStart, bool microRunning, 
    uint32_t ref32k){

  if (l->useTsMicro || r->useTsMicro){
    if (!microRunning){
      //at least one uses micro ref, but timer's not running.
      return l->useTsMicro ? TRUE : FALSE;
    }else if (l->useTsMicro && lastMicroStart > l->requestedTime){
      printf("L lms %lu > rt %lu\r\n", 
        lastMicroStart,
        l->requestedTime);
      //l was requested, but the micro timer was started some time
      // later, so l's tsMicro is no longer valid.
      return TRUE;
    }else if (r-> useTsMicro && lastMicroStart > r->requestedTime){
      printf("R lms %lu > rt %lu\r\n", 
        lastMicroStart,
        r->requestedTime);
      return FALSE;
    }else{
      //ok, micro times are valid!
    }
  }
  {
    //TODO: assess signed/unsigned threat here
    // A. apparently gcc is not quite smart enough here and leaves me
    //    with an unsigned int.
    // B. division rounds down, so 1 tick short = wrong
    //    frame
    int32_t lBaseDiff = (l->tsBase32k - ref32k);
    int32_t rBaseDiff = (l->tsBase32k - ref32k);
    int32_t lFrame;
    int32_t rFrame;
    if (lBaseDiff < 0){
      lFrame = l->frameOffset - (-1*lBaseDiff)/FRAMELEN_32K;
    }else{
      lFrame = l->frameOffset + (lBaseDiff)/FRAMELEN_32K;
    }
    if (rBaseDiff < 0){
      rFrame =  r->frameOffset - (-1*rBaseDiff)/FRAMELEN_32K;
    }else{
      rFrame =  r->frameOffset + (rBaseDiff)/FRAMELEN_32K ;
    }
    printf("lFrame: %li rFrame %li\r\n", lFrame, rFrame);

    if (lFrame < rFrame){
      return TRUE;
    }else if (rFrame < lFrame){
      return FALSE;
    }else{
      return l->requestType < r->requestType;
    }
  }

}


#endif
