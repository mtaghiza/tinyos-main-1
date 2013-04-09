#ifndef CX_SCHEDULER_DEBUG_H
#define CX_SCHEDULER_DEBUG_H

#if DEBUG_SCHED == 1
#define printf_SCHED( ... ) printf( __VA_ARGS__ )
#else
#define printf_SCHED(...)
#endif

#endif
