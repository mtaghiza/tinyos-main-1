#ifndef BASESTATION_H
#define BASESTATION_H

typedef nx_struct cx_download {
  nx_uint8_t networkSegment;
} cx_download_t;

typedef nx_struct cx_download_finished {
  nx_uint8_t networkSegment;
} cx_download_finished_t;

typedef nx_struct ctrl_ack {
  nx_uint8_t error;
} ctrl_ack_t;

enum {
  AM_CX_DOWNLOAD=0xD0,
  AM_CX_DOWNLOAD_FINISHED=0xD1,
  AM_CTRL_ACK=0xD2,
};

#endif
