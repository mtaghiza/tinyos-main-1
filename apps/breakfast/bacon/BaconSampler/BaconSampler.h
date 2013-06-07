#ifndef BACON_SAMPLER_H
#define BACON_SAMPLER_H

#define SS_KEY_BACON_SAMPLE_INTERVAL 0x14

typedef struct bacon_sample_t {
  uint8_t recordType;
  uint16_t rebootCounter;
  uint32_t baseTime;
  uint16_t battery;
  uint16_t light;
} __attribute__((packed)) bacon_sample_t;

#define RECORD_TYPE_BACON_SAMPLE 0x14

#endif
