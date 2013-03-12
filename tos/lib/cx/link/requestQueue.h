#ifndef REQUEST_QUEUE_H
#define REQUEST_QUEUE_H

#include "message.h"
#include "CXLink.h"

//sleep takes priority, then wakeup, then TX, and finally RX
typedef enum {
  RT_SLEEP = 0,
  RT_WAKEUP = 1,
  RT_TX = 2,
  RT_RX = 3,
} request_type_t;

typedef struct cx_request{
  uint32_t tsBase32k;
  uint8_t frameOffset;
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
      return l->tsMicro ? TRUE : FALSE;
    }else if (lastMicroStart > l->requestedTime){
      //l was requested, but the micro timer was started some time
      // later, so l's tsMicro is no longer valid.
      return TRUE;
    }else if (lastMicroStart > r->requestedTime){
      return FALSE;
    }else{
      //ok, micro times are valid!
    }
  }
  {
    //TODO: assess signed/unsigned threat here
    int32_t lFrame = ((l->tsBase32k - ref32k) / FRAMELEN_32K) +
      l->frameOffset;
    int32_t rFrame = ((r->tsBase32k - ref32k) / FRAMELEN_32K) +
      r->frameOffset;
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
