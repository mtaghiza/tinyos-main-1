#ifndef CX_AM_DEBUG_H
#define CX_AM_DEBUG_H

#if DEBUG_AM == 1
#define printf_AM( ... ) printf( __VA_ARGS__ )
#else
#define printf_AM(...)
#endif

#endif
