#ifndef CX_H
#define CX_H

typedef nx_struct cx_header_t {
  nx_am_addr_t destination;
  //would like to reuse the dsn in the 15.4 header, but it's not exposed in a clean way
  nx_uint8_t sn;
  nx_uint16_t count;
  nx_am_id_t type;
} cx_header_t;

#ifndef RETX_DELAY
#define RETX_DELAY 10240
#endif

#define CX_TYPE_DATA 0xaa

#endif
