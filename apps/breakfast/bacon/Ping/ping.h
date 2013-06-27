#ifndef PING_H
#define PING_H

typedef nx_struct ping_msg {
  nx_uint32_t pingId;
} ping_msg_t;

typedef nx_struct pong_msg {
  nx_uint32_t pingId;
  nx_uint16_t rebootCounter;
  nx_uint32_t tsMilli;
  nx_uint32_t ts32k;
} pong_msg_t;

enum {
  AM_PING_MSG = 0xF8,
  AM_PONG_MSG = 0xF9,
};

#endif
