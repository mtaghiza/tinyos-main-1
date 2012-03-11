#ifndef CXTDMA_H
#define CXTDMA_H

//Should be able to get this down to ~90 uS. 
// 100 uS = 108.3 ticks at 26mhz/24
#ifndef PFS_SLACK
#define PFS_SLACK 110
#endif

//10 ms at 26mhz/24
#ifndef DEFAULT_TDMA_FRAME_LEN
#define DEFAULT_TDMA_FRAME_LEN 10833U
#endif

//10 s at 26mhz/24
#ifndef DEFAULT_TDMA_FW_CHECK_LEN
#define DEFAULT_TDMA_FW_CHECK_LEN (10UL * 1000UL * DEFAULT_TDMA_FRAME_LEN)
#endif

#ifndef DEFAULT_TDMA_NUM_FRAMES
#define DEFAULT_TDMA_NUM_FRAMES 256
#endif

//TODO: this should be computed based on data rate.
//125000 bps -> 8uS per bit -> 64 uS per byte -> 512 uS for preamble +
//  synch = 554.66 ticks
#ifndef SFD_TIME
#define SFD_TIME 555
#endif

#endif
