#ifndef NSF_UNRELIABLE_BURST_H
#define NSF_UNRELIABLE_BURST_H

#if DEBUG_UB == 1
#define printf_UB(...) printf(__VA_ARGS__)
#else
#define printf_UB(...) 
#endif


typedef nx_struct nsf_setup_t{
  nx_am_addr_t src;
  nx_am_addr_t dest;
  nx_uint8_t distance;
} nsf_setup_t;

#endif
