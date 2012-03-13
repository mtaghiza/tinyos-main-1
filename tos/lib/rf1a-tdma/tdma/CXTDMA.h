#ifndef CXTDMA_H
#define CXTDMA_H

#ifndef TA_DIV
#define TA_DIV 1UL
#endif

#if TA_DIV == 1UL
#define TA_SCALE 6UL
#elif TA_DIV == 2UL
#define TA_SCALE 3UL
#elif TA_DIV == 3UL
#define TA_SCALE 2UL
#elif TA_DIV == 6UL
#define TA_SCALE 1UL
#else 
#error Only 1 (6.5 MHz) 2, 3, and 6 (1.083 MHz) TA_DIV supported!
#endif

//Should be able to get this down to ~90 uS. 
// 100 uS = 108.3 ticks at 26mhz/24
#ifndef PFS_SLACK_BASE
//this was too short at full speed.
//#define PFS_SLACK_BASE (110UL * (TA_SCALE))
#define PFS_SLACK_BASE (200UL * (TA_SCALE))
#endif

//10 ms at 26mhz/24
#ifndef DEFAULT_TDMA_FRAME_LEN_BASE
#define DEFAULT_TDMA_FRAME_LEN_BASE (10833UL * TA_SCALE)
#endif

//10 s at 26mhz/24
#ifndef DEFAULT_TDMA_FW_CHECK_LEN_BASE
#define DEFAULT_TDMA_FW_CHECK_LEN_BASE (10UL * 1000UL * DEFAULT_TDMA_FRAME_LEN_BASE)
#endif

#ifndef DEFAULT_TDMA_ACTIVE_FRAMES
#define DEFAULT_TDMA_ACTIVE_FRAMES 256
#endif

#ifndef DEFAULT_TDMA_INACTIVE_FRAMES
#define DEFAULT_TDMA_INACTIVE_FRAMES 0
#endif


//TODO: this should be computed based on data rate. Could also maybe
//  pick it up automatically by using carrier sense.
//125000 bps -> 8uS per bit -> 64 uS per byte -> 512 uS for preamble +
//  synch = 512 uS = 555 ticks at 26mhz/24
//  There's some extra time in here from the steps leading up to the
//  actual transmission (getting it from the upper layer, for
//  example). Which should actually be done the other way around, come
//  to think of it. So, we have to do this experimentally. 
#ifndef SFD_TIME
#if TA_DIV == 1
#define SFD_TIME 3530UL
#elif TA_DIV ==6
#define SFD_TIME 588UL
#else
  #error SFD_TIME not defined for this TA_DIV setting. Find by experiment.
#endif
#endif


#ifdef DEBUG_SCALE
#warning Scaling times for debug
#define TIMING_SCALE DEBUG_SCALE
#else
#define TIMING_SCALE 1
#endif


#define DEFAULT_TDMA_FRAME_LEN (DEFAULT_TDMA_FRAME_LEN_BASE * TIMING_SCALE)
#define DEFAULT_TDMA_FW_CHECK_LEN (DEFAULT_TDMA_FW_CHECK_LEN_BASE * TIMING_SCALE)
#define PFS_SLACK (PFS_SLACK_BASE * TIMING_SCALE)

#ifndef PORT_FS_TIMING
#define PORT_FS_TIMING P1OUT
#endif
#ifndef PIN_FS_TIMING
#define PIN_FS_TIMING 0x00
#endif

#ifndef PORT_PFS_TIMING
#define PORT_PFS_TIMING P1OUT
#endif
#ifndef PIN_PFS_TIMING
#define PIN_PFS_TIMING 0x00
#endif

#ifndef PORT_SC_TIMING
#define PORT_SC_TIMING P1OUT
#endif
#ifndef PIN_SC_TIMING
#define PIN_SC_TIMING 0x00
#endif


#endif
