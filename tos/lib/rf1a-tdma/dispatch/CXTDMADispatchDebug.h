#ifndef CXTDMA_DISPATCH_DEBUG_H
#define CXTDMA_DISPATCH_DEBUG_H

#ifdef DEBUG_SW_TOPO
#define printf_SW_TOPO(...) printf(__VA_ARGS__)
#else
#define printf_SW_TOPO(...) 
#endif

#ifdef DEBUG_TESTBED_RESOURCE
#define printf_TESTBED_RESOURCE(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_RESOURCE(...) 
#endif


#endif
