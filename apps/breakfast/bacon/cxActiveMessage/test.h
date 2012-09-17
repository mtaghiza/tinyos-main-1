#ifndef TEST_H
#define TEST_H

#define AM_ID_CX_TESTBED 0xdc

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

#if DEBUG_TMP == 1
#define printf_TMP(...) printf(__VA_ARGS__)
#else
#define printf_TMP(...) 
#endif

#ifndef TEST_IPI
#define TEST_IPI (60UL * 1024UL)
#endif

#ifndef RANDOMIZE_IPI
#define RANDOMIZE_IPI 1
#endif

#ifndef APP_SEND_TIMEOUT
#define APP_SEND_TIMEOUT (1024UL * 5UL)
#endif

#endif
