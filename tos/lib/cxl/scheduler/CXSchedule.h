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
#define RX_SLACK 5UL
#endif


//Could be off by one 32K tick
#define ASYNCHRONY_32K 198UL
//looks like around 100 uS between the tx strobe and the carrier sense
//  detection at the forwarder.
#define CS_PROPAGATION 650UL

//delay between the sched-layer frame timer.fired event and the link
//layer fastalarm.fired event. 
//TODO: This should be nowhere near this high, even if you take into
//account encoding time + transition from idle to FSTXON.
#define SCHED_TX_DELAY 3120UL

//Put it all together and convert to fast ticks
// - the slack itself
// - clock asynchrony
// - carrier sense prop time
// - delay between sender frame timer/actual tx start
#define DATA_TIMEOUT (ASYNCHRONY_32K + CS_PROPAGATION + SCHED_TX_DELAY + ((RX_SLACK * 2UL* FRAMELEN_FAST_NORMAL) / FRAMELEN_SLOW))

#define CTS_TIMEOUT (FRAMELEN_FAST_SHORT*CX_MAX_DEPTH)

#ifndef CX_DEFAULT_BW
#define CX_DEFAULT_BW 2
#endif

//This is in 32K ticks, not ms
#define CX_WAKEUP_LEN ((LPP_DEFAULT_PROBE_INTERVAL * CX_MAX_DEPTH) << 5)

//back to sleep when we miss this many CTS packets in a download.
#ifndef MISSED_CTS_THRESH
#define MISSED_CTS_THRESH 2
#endif

#endif
