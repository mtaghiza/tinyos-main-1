#ifndef AM_GLOSSY_H
#define AM_GLOSSY_H

typedef nx_struct am_glossy_header_t {
  //nested AM header
  nx_am_addr_t src;
  nx_am_addr_t dest;
  nx_am_id_t type;
  nx_am_group_t group;
  //glossy-specific
  nx_uint8_t count;
  nx_uint16_t sn;
} am_glossy_header_t;

#ifndef RETX_DELAY
//note that this is 64 ms at max in 16 bits (long enough for us?)
#define RETX_DELAY 65535UL
#endif

#endif
