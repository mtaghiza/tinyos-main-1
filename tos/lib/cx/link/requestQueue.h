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

#ifndef REQUEST_QUEUE_H
#define REQUEST_QUEUE_H

#include "message.h"
#include "CXLink.h"

//sleep takes priority, then wakeup, then TX, and finally RX.
//frameshift handled before "normal" events.
typedef enum {
  RT_SLEEP = 1,
  RT_WAKEUP = 2,
  RT_TX = 3,
  RT_RX = 4,
  RT_MARK = 5,
} request_type_t;

typedef enum {
  TXP_FORWARD = 0,
  TXP_SCHEDULED = 1,
  TXP_BROADCAST = 2,
  TXP_UNICAST = 3,
} tx_priority_t;

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
      uint32_t refFrame;
      uint32_t refTime;
      int32_t correction;
    } wakeup;
    struct{
      uint32_t duration;
    } rx;
    struct{
      bool useTsMicro;
      uint32_t tsMicro;
      nx_uint32_t* tsLoc;
      tx_priority_t txPriority;
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
      //NB: wraparound is not handled here, but it occurs after 1500
      //days so is probably not a practical concern.
      int32_t lfn = l->baseFrame + l->frameOffset;
      int32_t rfn = r->baseFrame + r->frameOffset;
  
      if (lfn < rfn){
        return TRUE;
      }else if (rfn < lfn){
        return FALSE;
      }else{
        if (l->requestType == RT_TX 
            && (l->requestType == r->requestType)){
          return l->typeSpecific.tx.txPriority <= r->typeSpecific.tx.txPriority;
        } else {

          return l->requestType <= r->requestType;
        }
      }
    }
  }
}

#endif
