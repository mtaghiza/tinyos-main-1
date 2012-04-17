#ifndef AODV_DEBUG_H
#define AODV_DEBUG_H

#if DEBUG_AODV == 1
#define printf_AODV(...) printf(__VA_ARGS__)
#else
#define printf_AODV(...) 
#endif

#if DEBUG_AODV_S == 1
#define printf_AODV_S(...) printf(__VA_ARGS__)
#else
#define printf_AODV_S(...) 
#endif

#if DEBUG_AODV_IO == 1
#define printf_AODV_IO(...) printf(__VA_ARGS__)
#else
#define printf_AODV_IO(...) 
#endif

#if DEBUG_AODV_STATE == 1
#define printf_AODV_STATE(...) printf(__VA_ARGS__)
#else
#define printf_AODV_STATE(...) 
#endif


#endif

