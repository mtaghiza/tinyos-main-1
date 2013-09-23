#ifndef AUTO_SENDER_H
#define AUTO_SENDER_H

#ifndef IS_SENDER
#define IS_SENDER 0
#endif

#ifndef DATA_RATE
#define DATA_RATE 0
#endif

#ifndef TEST_DESTINATION
#define TEST_DESTINATION 0xFFFF
#endif

#ifndef TEST_PAYLOAD_LEN
#define TEST_PAYLOAD_LEN 64
#endif

enum {
  AM_TEST_MSG = 0xdc,
};
#endif
