#ifndef CX_NETWORK_H
#define CX_NETWORK_H

typedef nx_struct cx_network_header {
  nx_uint8_t ttl;
  nx_uint8_t hops;
} cx_network_header_t;

typedef struct cx_network_metadata {
  uint32_t atFrame;
  uint32_t reqFrame;
  uint8_t  rxHopCount;
  uint32_t microRef;
  uint32_t t32kRef;
  void* next;
} cx_network_metadata_t;

#endif
