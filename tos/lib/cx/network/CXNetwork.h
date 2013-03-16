#ifndef CX_NETWORK_H
#define CX_NETWORK_H

typedef nx_struct cx_network_header {
  nx_uint8_t ttl;
  nx_uint8_t hops;
} cx_network_header_t;

#endif
