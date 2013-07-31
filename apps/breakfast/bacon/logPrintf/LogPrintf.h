#ifndef LOG_PRINTF_H
#define LOG_PRINTF_H

#define LOG_PRINTF_STR_LEN 50

#define RECORD_TYPE_LOG_PRINTF 0x18

typedef struct log_printf {
  uint8_t recordType;
  uint8_t str[LOG_PRINTF_STR_LEN];
  uint8_t len;
} log_printf_t;

#endif
