#ifndef SCHEDULE_H
#define SCHEDULE_H

#include "message.h"

#define CX_TYPE_SCHEDULE 0xac
#define CX_TYPE_SCHEDULE_REPLY 0xad

typedef nx_struct cx_schedule_t {
  nx_uint8_t scheduleNum;
  nx_uint16_t originalFrame;
  nx_uint32_t frameLen;
  nx_uint32_t fwCheckLen;
  nx_uint16_t activeFrames;
  nx_uint16_t inactiveFrames;
  nx_uint16_t framesPerSlot;
  nx_uint8_t  maxRetransmit;
  nx_uint8_t symbolRate;
  nx_uint8_t channel;
} cx_schedule_t;

typedef nx_struct cx_schedule_reply_t{
  nx_uint8_t scheduleNum;
} cx_schedule_reply_t;

#ifndef TDMA_ROOT
#define TDMA_ROOT 0
#endif

#endif
