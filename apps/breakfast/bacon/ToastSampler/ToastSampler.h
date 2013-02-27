#ifndef TOAST_SAMPLER_H
#define TOAST_SAMPLER_H

#include "GlobalID.h"
#include "ctrl_messages.h"
#include "I2CTLVStorage.h"

#ifndef MAX_BUS_LEN
#define MAX_BUS_LEN 4
#endif

#define RECORD_TYPE_TOAST_DISCONNECTED 0x10
#define RECORD_TYPE_TOAST_CONNECTED 0x11

//Heads-up: sensor_assignment_t is an nx type.
typedef struct toast_disconnection_record_t{
  uint8_t recordType;
  uint8_t globalAddr[GLOBAL_ID_LEN];
} toast_disconnection_record_t;

typedef struct toast_connection_record_t{
  uint8_t recordType;
  uint8_t tlvContents[SLAVE_TLV_LEN];
} __attribute__((packed)) toast_connection_record_t;


typedef struct sample_record_t{
  uint16_t rebootCounter;
  int32_t baseTime;
  uint8_t toastAddr[GLOBAL_ID_LEN];
  adc_sample_t samples[ADC_NUM_CHANNELS];
} __attribute__((packed)) sample_record_t;

#ifndef DEFAULT_SAMPLE_INTERVAL
#define DEFAULT_SAMPLE_INTERVAL (5UL*1024UL)
#endif

#define SS_KEY_SAMPLE_INTERVAL 0x12

#endif
