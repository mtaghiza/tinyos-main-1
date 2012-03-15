#ifndef SCHEDULE_H
#define SCHEDULE_H

#define CX_TYPE_SCHEDULE 0xab

typedef nx_struct cx_schedule_t {
  nx_uint16_t originalFrame;
  nx_uint32_t frameLen;
  nx_uint32_t fwCheckLen;
  nx_uint16_t activeFrames;
  nx_uint16_t inactiveFrames;
  nx_uint16_t framesPerSlot;
  nx_uint8_t  maxRetransmit;
  nx_uint32_t rootStart;
} cx_schedule_t;

#ifndef TDMA_ROOT
#define TDMA_ROOT FALSE
#endif

#endif
