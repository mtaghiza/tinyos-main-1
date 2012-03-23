#ifndef AODV_DEBUG_H
#define AODV_DEBUG_H

#ifdef DEBUG_AODV
#define printf_AODV(...) printf(__VA_ARGS__)
#else
#define printf_AODV(...) 
#endif

#endif

