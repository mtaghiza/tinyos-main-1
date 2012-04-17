#ifndef SCHEDULER_DEBUG_H
#define SCHEDULER_DEBUG_H

#if DEBUG_TESTBED_SCHED_NEW == 1
#define printf_TESTBED_SCHED_NEW(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_NEW(...)
#endif

#if DEBUG_TESTBED_SCHED_ALL == 1
#define printf_TESTBED_SCHED_ALL(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_ALL(...)
#endif

#if DEBUG_TESTBED_SCHED == 1
#define printf_TESTBED_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED(...)
#endif

#if DEBUG_TESTBED == 1
#define printf_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED(...)
#endif

#if DEBUG_TESTBED_CRC == 1
#define printf_TESTBED_CRC(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_CRC(...)
#endif

#if DEBUG_SCHED == 1
#define printf_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_SCHED(...)
#endif

#if DEBUG_SCHED_IO == 1
#define printf_SCHED_IO(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_IO(...)
#endif

#if DEBUG_SCHED_SR == 1
#define printf_SCHED_SR(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_SR(...)
#endif

#if DEBUG_TIMING == 1
#define printf_TIMING(...) printf(__VA_ARGS__)
#else
#define printf_TIMING(...)
#endif

#endif
