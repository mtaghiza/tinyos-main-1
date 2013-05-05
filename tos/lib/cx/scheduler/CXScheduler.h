#ifndef CX_SCHEDULER_H
#define CX_SCHEDULER_H

#include "AM.h"
#include "GlobalID.h"

#ifndef CX_STATIC_SCHEDULE
#define CX_STATIC_SCHEDULE 0
#endif

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

#ifndef CX_ENABLE_SKEW_CORRECTION
#define CX_ENABLE_SKEW_CORRECTION 1
#endif

#define INVALID_SCHEDULE 0xFF
#define INVALID_SLOT  0xFFFF
#define INVALID_FRAME 0xFFFFFFFF


typedef nx_struct cx_schedule_header {
  nx_uint8_t sn;
  nx_uint32_t originFrame;
}cx_schedule_header_t; 

#ifndef MAX_VACANT
#define MAX_VACANT 15
#endif

#ifndef MAX_FREED
#define MAX_FREED 5
#endif

typedef nx_struct cx_schedule {
  nx_uint8_t sn;
  nx_uint32_t cycleStartFrame;
  nx_uint32_t cycleLength;
  nx_uint16_t slotLength;
  nx_uint16_t activeSlots;
  nx_uint8_t maxDepth;
  nx_uint32_t timestamp; //32K timestamp of origin
  nx_uint8_t numVacant;
  nx_uint16_t vacantSlots[MAX_VACANT];
  nx_uint16_t freedSlots[MAX_FREED];
} cx_schedule_t;

//request just indicates how many slots this node wants to get.
typedef nx_struct cx_schedule_request {
  nx_uint8_t slotsRequested;
} cx_schedule_request_t;

typedef nx_struct cx_schedule_assignment {
  nx_am_addr_t owner;
  nx_uint16_t slotNumber;
} cx_schedule_assignment_t;

#ifndef MAX_ASSIGNMENTS
//15*6 = 91 bytes: should fit, even with headers etc.
#define MAX_ASSIGNMENTS 15
#endif

typedef nx_struct cx_assignment_msg {
  nx_uint8_t numAssigned;
  cx_schedule_assignment_t assignments[MAX_ASSIGNMENTS];
} cx_assignment_msg_t;

#ifndef CX_ENABLE_SKEW_CORRECTION 
#define CX_ENABLE_SKEW_CORRECTION 1
#endif

#ifndef SCHEDULE_LOSS_THRESHOLD
#define SCHEDULE_LOSS_THRESHOLD 2
#endif

#define AM_CX_SCHEDULE_MSG 0xC4
#define AM_CX_ASSIGNMENT_MSG 0xC5
#define AM_CX_REQUEST_MSG 0xC6

#define NO_OWNER AM_BROADCAST_ADDR
#define SCHEDULE 0xFFFE

#ifndef EVICTION_THRESHOLD 
#define EVICTION_THRESHOLD 5
#endif

#ifndef FREE_TIMEOUT
#define FREE_TIMEOUT 5
#endif

#endif
