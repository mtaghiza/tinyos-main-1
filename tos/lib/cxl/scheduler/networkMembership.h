#ifndef NETWORK_MEMBERSHIP_H
#define NETWORK_MEMBERSHIP_H

#ifndef MAX_NETWORK_MEMBERS
#define MAX_NETWORK_MEMBERS 25
#endif

typedef nx_struct network_membership
  nx_am_addr_t masterId;
  nx_uint8_t networkSegment;
  nx_uint8_t channel;
  nx_uint16_t rc;
  nx_uint32_t ts;
  nx_am_addr_t members[MAX_NETWORK_MEMBERS];
  nx_uint8_t distances[MAX_NETWORK_MEMBERS];
} network_membership_t;

#define RECORD_TYPE_NETWORK_MEMBERSHIP 0x19
#endif
