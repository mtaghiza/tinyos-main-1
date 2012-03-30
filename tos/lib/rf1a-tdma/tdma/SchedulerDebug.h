#ifndef SCHEDULER_DEBUG_H
#define SCHEDULER_DEBUG_H

#ifdef DEBUG_TESTBED_SCHED_NEW
#define printf_TESTBED_SCHED_NEW(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_NEW(...)
#endif

#ifdef DEBUG_TESTBED_SCHED_ALL
#define printf_TESTBED_SCHED_ALL(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_ALL(...)
#endif

#ifdef DEBUG_TESTBED_SCHED
#define printf_TESTBED_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED(...)
#endif

#ifdef DEBUG_TESTBED
#define printf_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED(...)
#endif

#ifdef DEBUG_TESTBED_CRC
#define printf_TESTBED_CRC(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_CRC(...)
#endif



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

#ifdef DEBUG_TIMING
#define printf_TIMING(...) printf(__VA_ARGS__)
#else
#define printf_TIMING(...)
#endif



#endif
