#ifndef CTRL_MESSAGES_H
#define CTRL_MESSAGES_H
typedef nx_struct test_msg{
  nx_uint8_t test;
} test_msg_t;

enum{
  AM_TEST_MSG = 100,
};
#endif
