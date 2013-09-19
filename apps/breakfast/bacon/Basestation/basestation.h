#ifndef BASESTATION_H
#define BASESTATION_H

#include "AM.h"
#include "message.h"

typedef struct queue_entry {
  message_t* msg;
  void* pl;
  uint8_t len;
} queue_entry_t;

typedef nx_struct cx_download_finished {
  nx_uint8_t networkSegment;
} cx_download_finished_t;

typedef nx_struct ctrl_ack {
  nx_uint8_t error;
} ctrl_ack_t;

typedef nx_struct status_time_ref {
  nx_am_addr_t node;
  nx_uint16_t rc;
  nx_uint32_t ts;
} status_time_ref_t;

typedef nx_struct identify_request {
  nx_uint8_t dummy;
} identify_request_t;

typedef nx_struct identify_response {
  nx_am_addr_t self;
} identify_response_t;

enum {
  AM_CX_DOWNLOAD_FINISHED=0xD1,
  AM_CTRL_ACK=0xD2,
  AM_STATUS_TIME_REF=0xD3,
  AM_IDENTIFY_REQUEST=0xD4,
  AM_IDENTIFY_RESPONSE=0xD5,
};

#endif
