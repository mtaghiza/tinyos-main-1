#ifndef RECORD_STORAGE_H
#define RECORD_STORAGE_H

#define MAX_RECORD_PACKET_LEN TOSH_DATA_LENGTH
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
  nx_uint8_t data[MAX_RECORD_PACKET_LEN];
} log_record_data_msg_t;

enum {
  AM_LOG_RECORD_DATA_MSG = 0xE0,
};

#endif
