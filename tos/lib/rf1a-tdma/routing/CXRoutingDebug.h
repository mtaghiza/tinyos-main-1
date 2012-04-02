#ifndef CX_ROUTING_DEBUG_H
#define CX_ROUTING_DEBUG_H

#ifdef DEBUG_ROUTING_TABLE
#define printf_ROUTING_TABLE(...) printf(__VA_ARGS__)
#else
#define printf_ROUTING_TABLE(...)
#endif

#endif
