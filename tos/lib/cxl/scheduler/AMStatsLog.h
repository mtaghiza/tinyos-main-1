#ifndef AM_STATS_LOG_H
#define AM_STATS_LOG_H

typedef nx_struct stats_log_radio {
  nx_uint8_t dummy;
} stats_log_radio_t;

typedef nx_struct stats_log_rx {
  nx_uint8_t dummy;
} stats_log_rx_t;

typedef nx_struct stats_log_tx {
  nx_uint8_t dummy;
} stats_log_tx_t;

enum {
  AM_STATS_LOG_RADIO=0xFA,
  AM_STATS_LOG_RX=0xFB,
  AM_STATS_LOG_TX=0xFC,
};

#endif
