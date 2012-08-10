#ifndef CXTDMA_DISPATCH_DEBUG_H
#define CXTDMA_DISPATCH_DEBUG_H

#if DEBUG_SW_TOPO == 1
#define printf_SW_TOPO(...) printf(__VA_ARGS__)
#else
#define printf_SW_TOPO(...) 
#endif

#if DEBUG_DUP == 1
#define printf_DUP(...) printf(__VA_ARGS__)
#else
#define printf_DUP(...) 
#endif


#if DEBUG_TESTBED_RESOURCE == 1
#define printf_TESTBED_RESOURCE(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_RESOURCE(...) 
#endif


#endif
