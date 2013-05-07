#ifndef CX_NETWORK_H
#define CX_NETWORK_H

typedef nx_struct cx_network_header {
  nx_uint8_t ttl;
  nx_uint8_t hops;
  nx_uint16_t sn;
} cx_network_header_t;

typedef struct cx_network_metadata {
  uint8_t layerCount;
  uint32_t reqFrame;
  uint32_t microRef;
  uint32_t t32kRef;
  nx_uint32_t* tsLoc;
  void* next;
} cx_network_metadata_t;

#ifndef CX_NETWORK_POOL_SIZE
//1 for forwarding, 1 for self. Expand if we ever support multiple
//  ongoing floods.
#define CX_NETWORK_POOL_SIZE 5
#endif

#ifndef CX_NETWORK_FORWARD_DELAY 
//forward received packet immediately.
#define CX_NETWORK_FORWARD_DELAY 1
#endif

#ifndef CX_SELF_RETX
#define CX_SELF_RETX 0
#endif

#define INVALID_TIMESTAMP 0xFFFFFFFF

#ifndef MAX_SOFT_SYNCH 
#define MAX_SOFT_SYNCH 1
#endif

#endif
