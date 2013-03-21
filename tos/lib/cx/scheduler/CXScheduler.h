#ifndef CX_SCHEDULER_H
#define CX_SCHEDULER_H

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

#define INVALID_SCHEDULE 0xFF

typedef nx_struct cx_schedule_header {
  nx_uint8_t sn;
  nx_uint32_t originFrame;
}cx_schedule_header_t; 

typedef nx_struct cx_schedule {
  nx_uint32_t timestamp; //32K timestamp of origin
  nx_uint32_t cycleLen;
  nx_uint32_t slotLen;
  nx_uint8_t numAssigned;
  nx_am_addr_t slotAssignments[CX_MAX_SLOTS];
} cx_schedule_t;

#endif
