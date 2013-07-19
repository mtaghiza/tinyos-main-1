#ifndef PHOENIX_H
#define PHOENIX_H

#define SS_KEY_PHOENIX_SAMPLE_INTERVAL 0x16 
#define SS_KEY_PHOENIX_TARGET_REFS 0x17 

#define RECORD_TYPE_PHOENIX 0x16

#ifndef DEFAULT_PHOENIX_TARGET_REFS
#define DEFAULT_PHOENIX_TARGET_REFS 1
#endif

#ifndef DEFAULT_PHOENIX_SAMPLE_INTERVAL
#define DEFAULT_PHOENIX_SAMPLE_INTERVAL (1024UL * 60UL * 60UL * 8UL)
#endif


#ifndef MAX_WASTED_SNIFFS
#define MAX_WASTED_SNIFFS 2
#endif

typedef struct phoenix_reference {
  uint8_t recordType;
  am_addr_t node2;
  uint16_t rc1;
  uint16_t rc2;
  uint32_t localTime1;
  uint32_t localTime2;
} __attribute__((packed)) phoenix_reference_t;

#endif
