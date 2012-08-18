#ifndef NSF_UNRELIABLE_BURST_DEBUG_H
#define NSF_UNRELIABLE_BURST_DEBUG_H

#if DEBUG_UB == 1
#define printf_UB(...) printf(__VA_ARGS__)
#else
#define printf_UB(...) 
#endif

#endif
