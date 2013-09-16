#ifndef CX_LPP_DEBUG_H
#define CX_LPP_DEBUG_H
#include "CXDebug.h"

#ifndef DL_LPP
#define DL_LPP DL_ERROR
#endif

#ifndef DL_LPP_PROBE
#define DL_LPP_PROBE DL_ERROR
#endif

#ifndef DL_PROBE_STATS
#define DL_PROBE_STATS DL_ERROR
#endif

//Setting this value to 1 means "never log"
#ifndef PROBE_LOG_INTERVAL
#define PROBE_LOG_INTERVAL 1
#endif

#endif

