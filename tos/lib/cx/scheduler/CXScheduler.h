#ifndef CX_SCHEDULER_H
#define CX_SCHEDULER_H

#include "AM.h"

#ifndef CX_MAX_SLOTS
#define CX_MAX_SLOTS 10
#endif

//max RX wait is 0xFFFFFFFF 6.5 MHz ticks, roughly 660 seconds
//20,000 frames is 625 seconds.
//This way, a node with no prior knowledge is guaranteed to be able to
//hear a transmission if it waits for max RX wait.
#ifndef CX_MAX_CYCLE_LENGTH
#define CX_MAX_CYCLE_LENGTH 20000
#endif

//2000 frames = 62.5 s ~= 1 minute
#ifndef CX_DEFAULT_CYCLE_LENGTH
#define CX_DEFAULT_CYCLE_LENGTH 2000
#endif

//in a 5-hop network, 10 frames to establish forwarder set, 5 frames
//per packet. 100 frames is enough for 18 packets at max depth.
#ifndef CX_DEFAULT_SLOT_LENGTH
#define CX_DEFAULT_SLOT_LENGTH 100
#endif

#ifndef CX_DEFAULT_MAX_DEPTH
#define CX_DEFAULT_MAX_DEPTH 10
#endif

#define INVALID_SCHEDULE 0xFF
#define INVALID_SLOT  0xFFFFFFFF
#define INVALID_FRAME 0xFFFFFFFF

typedef nx_struct cx_schedule_header {
  nx_uint8_t sn;
  nx_uint32_t originFrame;
}cx_schedule_header_t; 

typedef nx_struct cx_schedule {
  nx_uint8_t sn;
  nx_uint32_t cycleStartFrame;
  nx_uint32_t cycleLength;
  nx_uint32_t slotLength;
  nx_uint32_t activeSlots;
  nx_uint8_t maxDepth;
  nx_uint8_t numAssigned;
  nx_am_addr_t slotAssignments[CX_MAX_SLOTS];
  //have to place it at the end for timestamping to be happy
  nx_uint8_t padding0;
  nx_uint8_t padding1;
  nx_uint8_t padding2;
//  nx_uint8_t padding3;
  nx_uint32_t timestamp; //32K timestamp of origin
  nx_uint8_t padding4;
  nx_uint8_t padding5;
} cx_schedule_t;

#ifndef CX_ENABLE_SKEW_CORRECTION 
#define CX_ENABLE_SKEW_CORRECTION 1
#endif

#endif
