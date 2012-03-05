#ifndef CX_FLOOD_H
#define CX_FLOOD_H

#define CX_TYPE_FLOOD_ANNOUNCEMENT 0x00
#define CX_TYPE_FLOOD_DATA 0x01

typedef nx_struct cx_flood_announcement_t {
  nx_uint32_t period;
  nx_uint32_t frameLen;
  nx_uint16_t numFrames;
} cx_flood_announcement_t;

//TODO: these should both be derived from a single value. note that
//  XT2DIV is not a nice multiple of 2**15
#ifndef STARTSEND_SLACK_32KHZ
#define STARTSEND_SLACK_32KHZ 32
#endif
#ifndef STARTSEND_SLACK_XT2DIV
#define STARTSEND_SLACK_XT2DIV 1024
#endif

//TODO: tune this down as low as possible
#ifndef CX_FLOOD_RETX_DELAY
#define CX_FLOOD_RETX_DELAY 150
#endif

#ifndef CX_FLOOD_QUEUE_LEN
#define CX_FLOOD_QUEUE_LEN 16
#endif

#ifndef CX_FLOOD_FAILSAFE_LIMIT
#define CX_FLOOD_FAILSAFE_LIMIT 4
#endif

#ifndef CX_FLOOD_RADIO_START_SLACK
#define CX_FLOOD_RADIO_START_SLACK 10
#endif

//milliseconds
#ifndef CX_FLOOD_DEFAULT_PERIOD
#define CX_FLOOD_DEFAULT_PERIOD 5120
#endif

//32khz ticks: 256 = 8 ms
#ifndef CX_FLOOD_DEFAULT_FRAMELEN
#define CX_FLOOD_DEFAULT_FRAMELEN 256
#endif

#ifndef CX_FLOOD_DEFAULT_NUMFRAMES
#define CX_FLOOD_DEFAULT_NUMFRAMES 64
#endif

#endif
