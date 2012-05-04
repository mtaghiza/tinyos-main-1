#ifndef FEC_DEBUG_H
#define FEC_DEBUG_H

#if DEBUG_FEC == 1
#define printf_FEC(...) printf(__VA_ARGS__)
#else
#define printf_FEC(...) 
#endif

#endif
