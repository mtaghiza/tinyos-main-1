#ifndef SCHEDULE_H
#define SCHEDULE_H

#include "message.h"
#include "CXTDMA.h"
#include "TimingConstants.h"

#define CX_TYPE_SCHEDULE 0xac
#define CX_TYPE_SCHEDULE_REPLY 0xad

typedef nx_struct cx_schedule_t {
  nx_uint8_t scheduleNum;
  nx_uint8_t symbolRate;
  nx_uint8_t scheduleId;
//  nx_uint8_t padding[TOSH_DATA_LENGTH - sizeof(cx_header_t) -
//    sizeof(message_header_t) - 3*sizeof(nx_uint8_t) ];
} cx_schedule_t;

typedef struct cx_schedule_descriptor_t {
//  nx_uint32_t frameLen;
//  nx_uint32_t fwCheckLen;
  uint16_t activeFrames;
  uint16_t inactiveFrames;
  uint16_t framesPerSlot;
  uint8_t  maxRetransmit;
  uint8_t channel;
} cx_schedule_descriptor_t;

typedef nx_struct cx_schedule_reply_t{
  nx_uint8_t scheduleNum;
} cx_schedule_reply_t;

#ifndef TDMA_ROOT
#define TDMA_ROOT 0
#endif

//in units of frames, maybe that's dumb
#ifndef SCHEDULE_TIMEOUT
#define SCHEDULE_TIMEOUT 1024
#endif

#ifndef CX_ADAPTIVE_SR
#define CX_ADAPTIVE_SR 1
#endif

#if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
#ifndef TDMA_ROOT_FRAMES_PER_SLOT
#define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
#endif
#define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
#define TDMA_ROOT_INACTIVE_FRAMES 5
#else
#error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
#endif

#define TDMA_INIT_SCHEDULE_ID 0

const cx_schedule_descriptor_t SCHEDULES[1] = {
  { TDMA_ROOT_ACTIVE_FRAMES, TDMA_ROOT_INACTIVE_FRAMES,
  TDMA_ROOT_FRAMES_PER_SLOT, TDMA_MAX_RETRANSMIT, TEST_CHANNEL},
};



#endif
