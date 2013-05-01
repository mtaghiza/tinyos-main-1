#ifndef STACK_GUARD_H
#define STACK_GUARD_H

#include <sys/crtld.h>

//check every 100 ms by default
#ifndef STACKGUARD_CHECK_INTERVAL
#define STACKGUARD_CHECK_INTERVAL 3277
#endif

#ifndef STACKGUARD_CHECK_INTERVAL_MILLI
#define STACKGUARD_CHECK_INTERVAL_MILLI 1024
#endif

unsigned int* END_OF_STACK = __bss_end;
#endif
