#ifndef RECORD_REQUEST_H
#define RECORD_REQUEST_H


typedef nx_struct cx_record_request_msg {
  nx_uint16_t node_id;
  nx_uint32_t cookie;
  nx_uint8_t length;
} __attribute__((packed)) cx_record_request_msg_t;


enum {
  AM_CX_RECORD_REQUEST_MSG = 0xF0,
};

#endif
