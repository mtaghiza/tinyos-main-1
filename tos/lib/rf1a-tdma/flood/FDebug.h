#ifndef F_DEBUG_H
#define F_DEBUG_H

#ifdef DEBUG_F_STATE
#define printf_F_STATE(...) printf(__VA_ARGS__)
#else
#define printf_F_STATE(...) 
#endif

#ifdef DEBUG_F_RX
#define printf_F_RX(...) printf(__VA_ARGS__)
#else
#define printf_F_RX(...) 
#endif

#ifdef DEBUG_F_SCHED
#define printf_F_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_F_SCHED(...) 
#endif

#ifdef DEBUG_F_GP
#define printf_F_GP(...) printf(__VA_ARGS__)
#else
#define printf_F_GP(...) 
#endif


#endif
