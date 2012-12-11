#ifndef CONCXMIT_H
#define CONCXMIT_H

#include "message.h"


#define CONCXMIT_RADIO_AM_TEST 0xDC

#define CONCXMIT_SERIAL_AM_CMD 0xDC
#define CONCXMIT_SERIAL_AM_RECEIVER_REPORT 0xDD
#define CONCXMIT_SERIAL_AM_SENDER_REPORT 0xDE

typedef nx_struct {
  nx_uint16_t seqNum;
  nx_uint8_t data[0];
} test_packet_t;

#define CONCXMIT_CMD_NEXT 0x01
#define CONCXMIT_CMD_SEND 0x02


typedef nx_struct {
  nx_uint8_t cmd;
  nx_uint16_t send1Offset;
  nx_uint16_t sendCount;
} cmd_t;

typedef nx_struct{
  nx_uint16_t configId;
  nx_uint16_t seqNum;
  nx_uint8_t received;
  nx_uint16_t rssi;
  nx_uint16_t lqi;
  nx_uint16_t send1Offset;
} receiver_report_t;

typedef nx_struct{
  nx_uint16_t configId;
  nx_uint16_t seqNum;
} sender_report_t;


#endif
