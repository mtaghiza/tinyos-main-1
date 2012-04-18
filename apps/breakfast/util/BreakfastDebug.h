#ifndef BREAKFAST_DEBUG_H
#define BREAKFAST_DEBUG_H

#if DEBUG_BREAKFAST == 1
#define printf_BF(...) printf(__VA_ARGS__)
#else
#define printf_BF(...) 
#endif

#if DEBUG_TMP == 1
#define printf_TMP(...) printf(__VA_ARGS__)
#else
#define printf_TMP(...) 
#endif

#endif
