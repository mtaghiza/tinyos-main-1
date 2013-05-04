#ifndef TEST_H
#define TEST_H
#include "CXDebug.h"

#define AM_TEST_MSG 0xD0
#ifndef DESTINATION_ID 
#define DESTINATION_ID 0x00
#endif

#ifndef DL_test
#define DL_test DL_INFO
#endif

#ifndef PAYLOAD_LEN
#define PAYLOAD_LEN 50
#endif
typedef nx_struct test_payload {
  nx_uint8_t buffer[PAYLOAD_LEN];
  nx_uint32_t timestamp;
  nx_uint32_t sn;
} test_payload_t;

#endif
