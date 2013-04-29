#ifndef CX_TRANSPORT_DEBUG_H
#define CX_TRANSPORT_DEBUG_H

#if DEBUG_TRANSPORT == 1
#define printf_TRANSPORT( ... ) printf( __VA_ARGS__ )
#else
#define printf_TRANSPORT(...)
#endif

#endif
