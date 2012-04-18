#ifndef CXPACKET_DEBUG_H
#define CXPACKET_DEBUG_H

#if DEBUG_PACKET == 1
#define printf_PACKET(...) printf(__VA_ARGS__)
#else
#define printf_PACKET(...) 
#endif

#endif
