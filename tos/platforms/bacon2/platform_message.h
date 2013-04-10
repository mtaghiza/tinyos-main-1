
/**
 * @author Philip Levis
 * @author David Moss
 * @author Peter A. Bigot <pab@peoplepowerco.com>
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#ifndef PLATFORM_MESSAGE_H
#define PLATFORM_MESSAGE_H

#include "Rf1aPacket.h"
#include <Serial.h>

typedef union message_header {
  rf1a_ieee154_t rf1a_ieee154;
  serial_header_t serial;
} __attribute__((packed)) message_header_t;

typedef union TOSRadioFooter {
} message_footer_t;

typedef struct TOSRadioMetadata {
  rf1a_metadata_t rf1a;
} message_metadata_t;

#endif

