#ifndef RECORD_STORAGE_H
#define RECORD_STORAGE_H

#include "message.h"

#ifndef MAX_RECORD_PACKET_LEN
//give some breathing room in case we add more headers to packet.
#define MAX_RECORD_PACKET_LEN (TOSH_DATA_LENGTH - 8)
#endif

//most efficient way to pack them in, hope byte alignment isn't too
//much trouble.
typedef nx_struct log_record_t {
  nx_uint32_t cookie;
  nx_uint8_t length;
  nx_uint8_t data[0];
} __attribute__((packed)) log_record_t;

//this is going to be a bunch of variable-length records, so all we
//can do is give it a flat buffer.
typedef nx_struct log_record_data_msg {
  nx_uint16_t length;
  nx_uint8_t data[MAX_RECORD_PACKET_LEN - sizeof(nx_uint32_t) - sizeof(nx_uint16_t)];
  nx_uint32_t nextCookie;
} __attribute__((packed)) log_record_data_msg_t;

enum {
  AM_LOG_RECORD_DATA_MSG = 0xE0,
};

#endif
