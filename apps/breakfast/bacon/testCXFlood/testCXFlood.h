#ifndef TEST_CX_FLOOD_H
#define TEST_CX_FLOOD_H

#define CX_ID_TEST 0x02

#ifndef SEND_PERIOD
#define SEND_PERIOD 2048
#endif

typedef nx_struct test_packet_t{
  nx_uint32_t seqNum;
} test_packet_t;

#define NUM_POWER_LEVELS 4
int8_t POWER_LEVELS[NUM_POWER_LEVELS] =   {-12,  -6,   0,    10 };
int8_t POWER_SETTINGS[NUM_POWER_LEVELS] = {0x25, 0x2d, 0x8d, 0xc3 };

#endif
