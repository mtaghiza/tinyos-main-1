#ifndef TEST_H
#define TEST_H

#ifndef DEBUG_APP
#define DEBUG_APP 0
#endif

#if DEBUG_APP == 1
#define printf_APP(...) printf(__VA_ARGS__)
#else
#define printf_APP(...) 
#endif

#if DEBUG_TEST_QUEUE == 1
#define printf_TEST_QUEUE(...) printf(__VA_ARGS__)
#else
#define printf_TEST_QUEUE(...) 
#endif

#ifndef TEST_IPI
#define TEST_IPI (60UL * 1024UL)
#endif

#ifndef QUEUE_THRESHOLD
#define QUEUE_THRESHOLD 1
#endif

#endif
