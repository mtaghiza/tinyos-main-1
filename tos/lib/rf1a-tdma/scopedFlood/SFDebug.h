#ifndef SF_DEBUG_H
#define SF_DEBUG_H

#ifdef DEBUG_SF_STATE
#define printf_SF_STATE(...) printf(__VA_ARGS__)
#else
#define printf_SF_STATE(...)
#endif

#ifdef DEBUG_SF_GP
#define printf_SF_GP(...) printf(__VA_ARGS__)
#else
#define printf_SF_GP(...)
#endif

#ifdef DEBUG_SF_RX
#define printf_SF_RX(...) printf(__VA_ARGS__)
#else
#define printf_SF_RX(...)
#endif

#endif
