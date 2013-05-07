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

#ifndef SEND_THRESHOLD
#define SEND_THRESHOLD 1
#endif

#ifndef TEST_STARTUP_DELAY
#define TEST_STARTUP_DELAY (60UL*1024UL)
#endif

#ifndef TEST_DESTINATION
#define TEST_DESTINATION AM_BROADCAST_ADDR
#endif

#ifndef TEST_IPI 
#define TEST_IPI (60UL*1024UL)
#endif

#ifndef TEST_RANDOMIZE
#define TEST_RANDOMIZE (10UL*1024UL)
#endif


#endif
