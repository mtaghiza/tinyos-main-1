#ifndef AODV_DEBUG_H
#define AODV_DEBUG_H

#ifdef DEBUG_AODV
#define printf_AODV(...) printf(__VA_ARGS__)
#else
#define printf_AODV(...) 
#endif

#ifdef DEBUG_AODV_S
#define printf_AODV_S(...) printf(__VA_ARGS__)
#else
#define printf_AODV_S(...) 
#endif

#ifdef DEBUG_AODV_IO
#define printf_AODV_IO(...) printf(__VA_ARGS__)
#else
#define printf_AODV_IO(...) 
#endif

#endif

