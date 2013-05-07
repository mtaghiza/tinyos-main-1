#ifndef CX_SCHEDULER_DEBUG_H
#define CX_SCHEDULER_DEBUG_H

#include "CXDebug.h"

#ifndef DL_SCHED
#define DL_SCHED DL_INFO
#endif

#ifndef DL_SKEW
#define DL_SKEW DL_INFO
#endif

#ifndef DL_SKEW_APPLY
#define DL_SKEW_APPLY DL_WARN
#endif

#ifndef TEST_RESELECT
#define TEST_RESELECT 0
#endif

#endif
