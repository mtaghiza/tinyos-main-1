#ifndef ROUTER_H
#define ROUTER_H

#include "RecordStorage.h"
#define RECORD_TYPE_TUNNELED 0x15

typedef nx_struct tunneled_msg {
  nx_uint8_t recordType;
  nx_am_addr_t src;
  nx_am_id_t amId;
  nx_uint8_t data[MAX_RECORD_PACKET_LEN];
} tunneled_msg_t;

enum {
  AM_TUNNELED_MSG = 0x15,
};

#define SS_KEY_DOWNLOAD_INTERVAL 0x18

#ifndef DEFAULT_DOWNLOAD_INTERVAL
#define DEFAULT_DOWNLOAD_INTERVAL (12UL*60UL*60UL*1024UL)
#endif

//This is how long the router will wait before trying to download
//again if it gets an EBUSY (e.g. because it was already active doing
//a router download).
#define DOWNLOAD_RETRY_INTERVAL (60UL*60UL*1024UL)

#endif
