#ifndef REQUEST_QUEUE_H
#define REQUEST_QUEUE_H

#include "message.h"
#include "CXLink.h"

#include <stdio.h>

//sleep takes priority, then wakeup, then TX, and finally RX.
//frameshift handled before "normal" events.
typedef enum {
  RT_FRAMESHIFT = 0,
  RT_SLEEP = 1,
  RT_WAKEUP = 2,
  RT_TX = 3,
  RT_RX = 4,
  RT_MARK = 5,
} request_type_t;

//frame number increments every 2**-15 * 2**10 = 2**-5 seconds
//32 bit unsigned int: 2**32 * 2**-5 => 2**27 seconds to rollover
//there's between 2**16 and 2**17 seconds in a day (2**16.4)
//This comes out to ~1500 days between rollovers. so, we don't worry
//about it.
typedef struct cx_request{
  uint8_t layerCount;  //incremented on every requestX, decremented at
  // every xHandled. Passed along with all of the commands/events that
  // can affect the state of the priority queue.
  uint32_t baseFrame;
  int32_t frameOffset;
  uint32_t requestedTime;
  request_type_t requestType;
  //pointer to aux storage for next layer up
  void* next;
  message_t* msg;
  union{
    struct{
      uint32_t t32kRef;
      int32_t correction;
    } wakeup;
    struct{
      uint32_t duration;
    } rx;
    struct{
      bool useTsMicro;
      uint32_t tsMicro;
      nx_uint32_t* tsLoc;
    } tx;
  } typeSpecific;
} cx_request_t;

bool requestLeq(cx_request_t* l, cx_request_t* r){
  { 
    //NULL's are always considered to have lowest priority.
    if(l == NULL){
      return FALSE;
    }else if (r == NULL){
      return TRUE;
    } else {
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
}

#endif
