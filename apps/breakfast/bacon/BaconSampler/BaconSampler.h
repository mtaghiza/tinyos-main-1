#ifndef BACON_SAMPLER_H
#define BACON_SAMPLER_H

#define SS_KEY_BACON_SAMPLE_INTERVAL 0x14

typedef struct bacon_sample_t {
  uint8_t recordType;
  uint16_t rebootCounter;
  uint32_t baseTime;
  uint16_t battery;
  uint16_t light;
  uint16_t thermistor;
} __attribute__((packed)) bacon_sample_t;

#define RECORD_TYPE_BACON_SAMPLE 0x14

#ifndef CONFIGURABLE_BACON_SAMPLE_INTERVAL
#define CONFIGURABLE_BACON_SAMPLE_INTERVAL 1
#endif

#if CONFIGURABLE_BACON_SAMPLE_INTERVAL != 1
#warning Non-configurable bacon sample interval.
#endif

#endif
