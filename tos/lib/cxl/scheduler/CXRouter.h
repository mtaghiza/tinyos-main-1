#ifndef CX_ROUTER_H
#define CX_ROUTER_H

#include "AM.h"

typedef nx_struct cx_download {
  nx_uint8_t networkSegment;
  nx_uint8_t padding[8];
} cx_download_t;

enum{
  AM_CX_DOWNLOAD=0xD0,
};

typedef struct contact_entry{
  am_addr_t nodeId;
  uint8_t failedAttempts;
  bool dataPending;
  bool contactFlag;
} contact_entry_t;

#ifndef CX_MAX_SUBNETWORK_SIZE
#define CX_MAX_SUBNETWORK_SIZE 60
#endif

#define SS_KEY_MAX_DOWNLOAD_ROUNDS 0x19

#ifndef DEFAULT_MAX_DOWNLOAD_ROUNDS
#define DEFAULT_MAX_DOWNLOAD_ROUNDS 10
#endif

#ifndef DEFAULT_MAX_ATTEMPTS
#define DEFAULT_MAX_ATTEMPTS 2
#endif

#endif
