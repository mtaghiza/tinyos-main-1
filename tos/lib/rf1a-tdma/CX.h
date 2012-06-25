#ifndef CX_H
#define CX_H

#include "AM.h"
typedef nx_uint8_t cx_routing_method_t;

//size: 19 (18 if am_id is 1 byte)
typedef nx_struct cx_header_t {
  nx_am_addr_t destination;
  //would like to reuse the dsn in the 15.4 header, but it's not exposed in a clean way
  nx_uint16_t sn;
  nx_uint8_t count;
  nx_uint8_t scheduleNum;
  nx_uint16_t originalFrameNum;
  nx_uint32_t timestamp;
  nx_uint8_t nProto;
  nx_uint8_t tProto;
  nx_uint8_t type;
} cx_header_t;

enum{
  CX_RM_FLOOD = 0x01,
  CX_RM_SCOPEDFLOOD = 0x02,
  CX_RM_AODV = 0x03,
  CX_RM_PREROUTED = 0x10,
  CX_RM_NONE = 0x00,
};

typedef nx_struct cx_ack_t{
  //DATA source id/sn
  nx_am_addr_t src;
  nx_uint16_t sn;
  //how far away the dest is from the source.
  nx_uint8_t depth;
} cx_ack_t;

typedef struct cx_metadata_t{
  uint8_t receivedCount;
  uint32_t phyTimestamp;
  uint32_t alarmTimestamp;
  uint16_t frameNum;
  uint8_t symbolRate;
  bool requiresClear;
} cx_metadata_t;

#define CX_TYPE_DATA 0xaa
#define CX_TYPE_ACK  0xab
#define CXTDMA_RM_RESOURCE "CXTDMA.RM.Resource"

#ifndef CX_MESSAGE_POOL_SIZE
#define CX_MESSAGE_POOL_SIZE 4
#endif

#endif
