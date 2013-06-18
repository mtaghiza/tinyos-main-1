#ifndef TEST_H
#define TEST_H

#include "CXDebug.h"

#ifndef PAYLOAD_LEN 
#define PAYLOAD_LEN 10
#endif

typedef nx_struct test_payload{
  nx_uint8_t body[PAYLOAD_LEN];
  nx_uint32_t timestamp;
} test_payload_t;

enum {
  AM_TEST_PAYLOAD=0xDC,
};

#ifndef DL_APP 
#define DL_APP DL_INFO
#endif
#endif
