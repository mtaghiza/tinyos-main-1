#ifndef PLATFORM_MESSAGE_H
#define PLATFORM_MESSAGE_H

#ifndef TOSH_DATA_LENGTH
//The maximum packet we can send with FEC is 127 bytes (2x packet len
//< 255). The link header is 10 bytes long, so the longest DL is 117.
//By setting this to 110, we give ourselves a little breathing room in
//case we end up having to extend the header (e.g. to put in
//timestamp information)
#define TOSH_DATA_LENGTH 110
#endif

#include "CXLink.h"
#include "Rf1aPacket.h"
#include "Serial.h"

typedef union message_header {
  cx_link_header_t cx_link_header;
  serial_header_t serial_header;
} __attribute__((packed)) message_header_t;

typedef struct TOSRadioFooter {
  nx_uint8_t paddingByte;
  nx_uint16_t checksum;
} message_footer_t;

typedef struct TOSRadioMetadata {
  cx_link_metadata_t cx;
  rf1a_metadata_t rf1a;
} message_metadata_t;
#endif
