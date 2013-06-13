#ifndef CX_MAC_H
#define CX_MAC_H

#define CXM_DATA 0
#define CXM_PROBE 1
#define CXM_KEEPALIVE 2
#define CXM_CTS 3
#define CXM_RTS 4
//TODO: maybe add acks

typedef nx_struct cx_mac_header{
  nx_uint8_t macType;
} cx_mac_header_t;

#endif
