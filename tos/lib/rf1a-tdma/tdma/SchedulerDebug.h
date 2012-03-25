#ifndef SCHEDULER_DEBUG_H
#define SCHEDULER_DEBUG_H

#ifdef DEBUG_SCHED
#define printf_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_SCHED(...)
#endif

#ifdef DEBUG_SCHED_IO
#define printf_SCHED_IO(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_IO(...)
#endif

#ifdef DEBUG_SCHED_SR
#define printf_SCHED_SR(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_SR(...)
#endif



#endif
