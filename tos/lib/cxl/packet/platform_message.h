#ifndef PLATFORM_MESSAGE_H
#define PLATFORM_MESSAGE_H

#include "CXLink.h"
#include "Rf1aPacket.h"
#include "Serial.h"

typedef union message_header {
  cx_link_header_t cx_link_header;
  serial_header_t serial_header;
} __attribute__((packed)) message_header_t;

typedef struct TOSRadioFooter {
  nx_uint16_t checksum;
} message_footer_t;

typedef struct TOSRadioMetadata {
  cx_link_metadata_t cx;
  rf1a_metadata_t rf1a;
} message_metadata_t;
#endif
