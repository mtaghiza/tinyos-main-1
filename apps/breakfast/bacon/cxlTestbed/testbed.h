#ifndef TESTBED_H
#define TESTBED_H

#include "multiNetwork.h"

#ifndef STARTUP_DELAY
#define STARTUP_DELAY (60UL*1024UL)
#endif

#ifndef TEST_SEGMENT
#define TEST_SEGMENT NS_SUBNETWORK
#endif

#define TEST_DELAY (LPP_SLEEP_TIMEOUT * 2UL)

#endif
