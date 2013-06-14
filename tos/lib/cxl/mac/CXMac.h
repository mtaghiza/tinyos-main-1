#ifndef CX_MAC_H
#define CX_MAC_H

#include "CXLink.h"

#define CXM_DATA 0
#define CXM_PROBE 1
#define CXM_KEEPALIVE 2
#define CXM_CTS 3
#define CXM_RTS 4
//TODO: maybe add acks

typedef nx_struct cx_mac_header{
  nx_uint8_t macType;
} cx_mac_header_t;

#ifndef LPP_DEFAULT_PROBE_INTERVAL
#define LPP_DEFAULT_PROBE_INTERVAL 5120UL
#endif

#ifndef LPP_SLEEP_TIMEOUT
#define LPP_SLEEP_TIMEOUT 30720UL
#endif

#define CX_KEEPALIVE_RETRY 512UL

#define CHECK_TIMEOUT (FRAMELEN_FAST + (FRAMELEN_FAST/2))
#define RX_TIMEOUT_MAX (0xFFFFFFFF)

#define MAC_RETRY_LIMIT 4

#ifndef CX_BASESTATION 
#define CX_BASESTATION 0
#endif

#endif
