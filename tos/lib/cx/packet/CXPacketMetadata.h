#ifndef CX_PACKET_METADATA_H
#define CX_PACKET_METADATA_H

typedef struct cx_metadata {
  uint32_t originFrameNumber;
  uint32_t originFrameStart;
  uint8_t rxHopCount;
} cx_metadata_t;

#endif
