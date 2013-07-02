#ifndef CX_SCHEDULE_H
#define CX_SCHEDULE_H

#include "CXLink.h"

#define FRAME_LENGTH FRAMELEN_SLOW

#ifndef FRAMES_PER_SLOT
#define FRAMES_PER_SLOT 30
#endif

#define SLOT_LENGTH FRAME_LENGTH * FRAMES_PER_SLOT

//This is the time, in 32k ticks, by which receivers attempt to
//  precede the sender. If they are perfectly synchronized, then the
//  IDLE ->RX time and the IDLE->TX time are equal (88 uS). 3 ticks is
//  91 uS, so we can miss by a lot and still hit it.
#ifndef RX_SLACK
#define RX_SLACK 3UL
#endif

//The timeout for a normal frame-aligned transmission is 2x RX_SLACK.
//We need to convert this to fast ticks, though.
#define DATA_TIMEOUT (RX_SLACK * 2UL * FRAMELEN_FAST_NORMAL) / FRAMELEN_SLOW

#define CTS_TIMEOUT (FRAMELEN_FAST_SHORT*CX_MAX_DEPTH)

#define CX_DEFAULT_BW 2

//This is in 32K ticks, not ms
#define CX_WAKEUP_LEN ((LPP_DEFAULT_PROBE_INTERVAL * CX_MAX_DEPTH) << 5)

#endif
