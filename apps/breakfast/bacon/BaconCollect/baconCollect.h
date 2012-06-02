#ifndef bacon_collect_h
#define bacon_collect_h

#include "I2CADCReader.h"

#define DEFAULT_GATEWAY (0x0000)
#define SAMPLE_POOL_SIZE (4)
#define SEND_POOL_SIZE (8)

#define BACON_SAMPLE_INTERVAL (1024UL * 1 * 1)
#define TOAST_SAMPLE_INTERVAL (1024UL * 10 * 1)
#define STATUS_SAMPLE_INTERVAL (1024UL * 10 * 1)

#define CLOCK_INTERVAL (1024UL * 60 * 60)
#define STATUS_INTERVAL (1024UL * 60 * 60)
#define FLASH_MAX_READ (254)

  enum {
    CONTROL_CHANNEL,
    MASTER_CONTROL_CHANNEL,
    PERIODIC_CHANNEL
  };

  enum {
    TYPE_SAMPLE_BACON,
    TYPE_SAMPLE_TOAST,
    TYPE_SAMPLE_CLOCK,
    TYPE_SAMPLE_STATUS,
    TYPE_CONTROL_SET_COOKIE,
    TYPE_CONTROL_BLINK,
    TYPE_CONTROL_BLINK_LINK,
    TYPE_CONTROL_BLINK_PROBE,
    TYPE_CONTROL_CLOCK,
    TYPE_CONTROL_PANIC,
    TYPE_LOCAL_STATUS
  };



  typedef struct {
    nx_uint8_t length;
    nx_uint8_t type;
    nx_uint16_t source;
    nx_uint16_t destination;
    nx_uint32_t field32;
    nx_uint8_t field8;
    nx_uint8_t array7[7];
  } __attribute__ ((__packed__)) control_t;

  typedef struct {
    nx_uint8_t length;
    nx_uint8_t type;
    nx_uint16_t source;
    nx_uint32_t flash;
    nx_uint8_t boot;
    nx_uint32_t time;
  } __attribute__ ((__packed__)) sample_header_t;

  typedef struct {
    sample_header_t info;

    nx_uint16_t battery;
    nx_uint16_t light;
    nx_uint16_t temp;

    nx_uint16_t crc;
  } __attribute__ ((__packed__)) sample_bacon_t;

  typedef struct {
    sample_header_t info;

    nx_uint32_t id;
    nx_uint16_t sample[ADC_NUM_CHANNELS - 1];
    nx_uint16_t crc;
  } __attribute__ ((__packed__)) sample_toast_t;

  typedef struct {
    sample_header_t info;

	nx_uint16_t reference;
    nx_uint8_t boot;
    nx_uint32_t time;
    nx_uint8_t rtc[7];
    nx_uint16_t crc;
  } __attribute__ ((__packed__)) sample_clock_t;

  typedef struct {
    sample_header_t info;

	nx_uint8_t writeQueue;
	nx_uint8_t sendQueue;
	nx_uint32_t radioOnTime;
	nx_uint32_t radioOffTime;
    nx_uint16_t crc;
  } __attribute__ ((__packed__)) sample_status_t;

#define SAMPLE_MAX_SIZE (sizeof(sample_toast_t))

typedef sample_toast_t sample_t;


#endif