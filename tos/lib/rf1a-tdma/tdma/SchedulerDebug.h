#ifndef SCHEDULER_DEBUG_H
#define SCHEDULER_DEBUG_H

#ifdef DEBUG_SCHED
#define printf_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_SCHED(...)
#endif
#endif
