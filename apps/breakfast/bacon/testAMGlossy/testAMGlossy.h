#ifndef TEST_AM_GLOSSY_H
#define TEST_AM_GLOSSY_H

typedef nx_struct test_packet_t{
  nx_uint32_t seqNum;
} test_packet_t;

#ifndef TEST_CHANNEL
#define TEST_CHANNEL 64
#endif

#ifndef TEST_POWER_INDEX
#define TEST_POWER_INDEX 0
#endif

#define NUM_POWER_LEVELS 4
int8_t POWER_LEVELS[NUM_POWER_LEVELS] =   {-12,  -6,   0,    10 };
int8_t POWER_SETTINGS[NUM_POWER_LEVELS] = {0x25, 0x2d, 0x8d, 0xc3 };

#endif
