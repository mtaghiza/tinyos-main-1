#ifndef CX_LINK_H
#define CX_LINK_H

#include "requestQueue.h"

#ifndef REQUEST_QUEUE_LEN 
//cycle sleep/wake, forward sleep/wake, net tx, trans tx, rx
#define REQUEST_QUEUE_LEN 10
#endif

//32k = 2**15
#define FRAMELEN_32K 1024
//6.5M = 2**5 * 5**16 * 13
#define FRAMELEN_6_5M 203125UL
//divide both by 2**5, this is what you get.
//1024 32k ticks = 0.03125 s
//n.b. it seems like mspgcc is smart enough to see /1024 and translate
//it to >> 10. so, it's fine to divide by this defined constant.

//TODO: FIXME define these.
#define MIN_FASTALARM_SLACK 0UL
//3250 = 0.5 ms
#define RX_DEFAULT_WAIT 3250UL

#endif
