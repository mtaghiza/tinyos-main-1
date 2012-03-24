#ifndef BREAKFAST_DEBUG_H
#define BREAKFAST_DEBUG_H

#ifdef DEBUG_BREAKFAST
#define printf_BF(...) printf(__VA_ARGS__)
#else
#define printf_BF(...) 
#endif

#endif
