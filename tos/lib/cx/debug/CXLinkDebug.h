#ifndef CX_LINK_DEBUG_H
#define CX_LINK_DEBUG_H

#ifndef LINK_DEBUG_FRAME_BOUNDARIES 
#define LINK_DEBUG_FRAME_BOUNDARIES 0
#endif

#ifndef LINK_DEBUG_WAKEUP 
#define LINK_DEBUG_WAKEUP 0
#endif

#ifndef DEBUG_LINK
#define DEBUG_LINK 0
#endif

#if DEBUG_LINK == 1
#define printf_LINK( ... ) printf( __VA_ARGS__ )
#else
#define printf_LINK(...)
#endif

#ifndef DEBUG_LINK_EVICTIONS
#define DEBUG_LINK_EVICTIONS 0
#endif

#if DEBUG_LINK_EVICTIONS == 1
#define printf_LINK_EVICTIONS( ... ) printf( __VA_ARGS__ )
#else
#define printf_LINK_EVICTIONS(...)
#endif

#endif
