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

#endif
