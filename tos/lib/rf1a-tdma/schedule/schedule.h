#ifndef SCHEDULE_H
#define SCHEDULE_H

#define AM_ID_LEAF_SCHEDULE 0xE0
#define AM_ID_LEAF_REQUEST 0xE1
#define AM_ID_LEAF_RESPONSE 0xE2

#define AM_ID_ROUTER_SCHEDULE 0xF0
#define AM_ID_ROUTER_REQUEST 0xF1
#define AM_ID_ROUTER_RESPONSE 0xF2

#define CX_SCHEDULER_MASTER 0x00
#define CX_SCHEDULER_SLAVE 0x01

#ifndef MAX_ANNOUNCED_SLOTS
#define MAX_ANNOUNCED_SLOTS 5
#endif

#ifndef SCHED_NUM_SLOTS
#define SCHED_NUM_SLOTS 10
#endif

#ifndef SCHED_FRAMES_PER_SLOT
#define SCHED_FRAMES_PER_SLOT 10
#endif

enum {
  UNCLAIMED = 0xffff,
};

typedef struct assignment_t {
  am_addr_t owner;
  uint8_t absentCycles;
  bool notified;
} assignment_t;

typedef nx_struct cx_schedule_t {
  nx_uint8_t scheduleNum;  //incremented if any parameters change
                           // which would result in a synch loss were
                           // they not received
  nx_uint8_t symbolRate;   //data rate in kbps
  nx_uint8_t channel;
  nx_uint16_t slots;      //total slots in cycle
  nx_uint16_t framesPerSlot; 
  nx_uint8_t  maxRetransmit;
  nx_uint16_t firstIdleSlot; //range of cycle with no traffic
  nx_uint16_t lastIdleSlot;
  nx_uint8_t numAvailableSlots; //how many free slots are being announced
  nx_uint16_t availableSlots[MAX_ANNOUNCED_SLOTS]; //the free slots
} cx_schedule_t;

#endif
